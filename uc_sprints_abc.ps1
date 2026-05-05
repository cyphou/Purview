# UC Sprints A + B + C — combined execution
# A.4: Add acronyms to UC terms
# B.2: Link UC Data Products to Atlas Business Processes
# B.4: Bulk-attach more assets to DPs (keyword expansion)
# C.1: Update KR progress on our 5 LoB Objectives

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api    = "?api-version=2026-03-20-preview"

$summary = [ordered]@{}

# ============================================================
# SPRINT A.4 — Add acronyms to UC terms
# ============================================================
Write-Host "`n=== SPRINT A.4: Add acronyms to UC terms ===" -ForegroundColor Cyan

# Map of term-name -> acronyms[]
$termAcronyms = @{
    "Overall Equipment Effectiveness"   = @("OEE")
    "Mean Time Between Failures"        = @("MTBF")
    "Mean Time To Repair"               = @("MTTR")
    "Net Promoter Score"                = @("NPS")
    "Customer Lifetime Value"           = @("CLV", "LTV")
    "Average Revenue Per User"          = @("ARPU")
    "Customer Satisfaction"             = @("CSAT")
    "Total Recordable Incident Rate"    = @("TRIR")
    "Earnings Before Interest, Taxes, Depreciation, and Amortization" = @("EBITDA")
    "Cost of Goods Sold"                = @("COGS")
    "Operating Expenses"                = @("OpEx")
    "Capital Expenditure"               = @("CapEx")
    "Key Performance Indicator"         = @("KPI")
    "Service Level Agreement"           = @("SLA")
    "Annual Recurring Revenue"          = @("ARR")
    "Mean Time To Detect"               = @("MTTD")
    "Personally Identifiable Information" = @("PII")
}

# Get all UC terms (paginated — fetch all)
$allTerms = @()
$skipToken = $null
do {
    $url = "$dgBase/terms$api&top=200"
    if ($skipToken) { $url += "&skipToken=$skipToken" }
    $page = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $allTerms += $page.value
    $skipToken = if ($page.nextLink) { ($page.nextLink -split 'skipToken=')[1] } else { $null }
} while ($skipToken)

Write-Host "  Loaded $($allTerms.Count) UC terms"

$acrUpdated = 0
foreach ($pair in $termAcronyms.GetEnumerator()) {
    $t = $allTerms | Where-Object { $_.name -eq $pair.Key } | Select-Object -First 1
    if (-not $t) { continue }
    if ($t.acronyms -and ($t.acronyms -join ',') -eq ($pair.Value -join ',')) { continue }
    $body = @{
        id           = $t.id
        name         = $t.name
        status       = "Published"
        domain       = $t.domain
        description  = $t.description
        contacts     = $t.contacts
        acronyms     = $pair.Value
    }
    if ($t.resources) { $body.resources = $t.resources }
    $json = $body | ConvertTo-Json -Depth 8
    try {
        $r = Invoke-RestMethod -Uri "$dgBase/terms/$($t.id)$api" -Headers $headers -Method Put -Body $json
        Write-Host "  ✓ $($t.name) ← [$($pair.Value -join ', ')]"
        $acrUpdated++
    } catch {
        $msg = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        Write-Host "  ✗ $($t.name) :: $msg" -ForegroundColor Red
    }
}
$summary["Sprint A.4 — Term acronyms added"] = "$acrUpdated terms"

# ============================================================
# SPRINT B.2 — Probe + link UC Data Products to Atlas Business Processes
# ============================================================
Write-Host "`n=== SPRINT B.2: Link DPs → BusinessProcesses ===" -ForegroundColor Cyan

# Atlas BP GUIDs from Sprint 6
$BP = @{
    PlanToReport          = "16089eb0-282a-4b82-824b-1ce618804ee3"
    OrderToCash           = "5da382a9-2fad-4667-b4c5-52ab233e95b7"
    HireToRetire          = "43542364-a785-4c02-a8cd-5a7203105e4c"
    EquipToMaintenance    = "c91a1778-8e5f-4b50-85e8-5d9e33f370ee"
    DataAssetToInsight    = "24b3ece6-e83d-46ce-9e74-236e0b437790"
}

$DP = @{
    ExecFinDashboards    = "4baeadc4-224c-43be-93a5-819ed2fb9e97"
    ESGCSRD              = "c5e22498-7d09-41b1-a059-3ae5398f7a49"
    Customer360          = "dd58e805-6ac3-4566-b785-03fec789610c"
    WorkforceAnalytics   = "62ad4ddf-1042-49ec-a24e-1181cc737dad"
    OperationalPerf      = "4302076b-110d-4344-85f7-3c41c34d0b82"
    DataPlatformHealth   = "2493e522-afff-4289-8595-1cf20c9db42d"
}

$dpBPmap = @(
    @{ dp=$DP.ExecFinDashboards;  bp=$BP.PlanToReport;       name="ExecFinDashboards → Plan-to-Report" },
    @{ dp=$DP.ESGCSRD;            bp=$BP.PlanToReport;       name="ESGCSRD → Plan-to-Report" },
    @{ dp=$DP.Customer360;        bp=$BP.OrderToCash;        name="Customer360 → Order-to-Cash" },
    @{ dp=$DP.WorkforceAnalytics; bp=$BP.HireToRetire;       name="WorkforceAnalytics → Hire-to-Retire" },
    @{ dp=$DP.OperationalPerf;    bp=$BP.EquipToMaintenance; name="OperationalPerf → Equipment-to-Maintenance" },
    @{ dp=$DP.DataPlatformHealth; bp=$BP.DataAssetToInsight; name="DataPlatformHealth → Data-Asset-to-Insight" }
)

# Probe entityType values
$probeTypes = @("BusinessProcess", "Purview_BusinessProcess", "Process", "Asset")
$workingType = $null
foreach ($et in $probeTypes) {
    try {
        $body = @{ entityId = $BP.PlanToReport } | ConvertTo-Json
        $r = Invoke-WebRequest -Uri "$dgBase/dataproducts/$($DP.ExecFinDashboards)/relationships$api&entityType=$et" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) {
            Write-Host "  ✓ entityType='$et' WORKS (HTTP $($r.StatusCode))"
            $workingType = $et
            break
        } else {
            Write-Host "  ✗ entityType='$et' → HTTP $($r.StatusCode)"
        }
    } catch {
        Write-Host "  ✗ entityType='$et' → exception"
    }
}

$bpLinked = 0
if ($workingType) {
    foreach ($m in $dpBPmap) {
        if ($m.dp -eq $DP.ExecFinDashboards -and $m.bp -eq $BP.PlanToReport) { $bpLinked++; continue }  # already done in probe
        $body = @{ entityId = $m.bp } | ConvertTo-Json
        try {
            $r = Invoke-WebRequest -Uri "$dgBase/dataproducts/$($m.dp)/relationships$api&entityType=$workingType" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300) {
                Write-Host "  ✓ $($m.name)"
                $bpLinked++
            } else {
                $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
                Write-Host "  ✗ $($m.name) → HTTP $($r.StatusCode): $content" -ForegroundColor Red
            }
        } catch { Write-Host "  ✗ $($m.name) → exception" -ForegroundColor Red }
    }
}
$summary["Sprint B.2 — DP→BP relationships"] = if ($workingType) { "$bpLinked / 6 (entityType=$workingType)" } else { "BLOCKED — no entityType accepted for BusinessProcess" }

# ============================================================
# SPRINT C.1 — Update KR progress on our 5 LoB Objectives
# ============================================================
Write-Host "`n=== SPRINT C.1: Update KR progress on LoB Objectives ===" -ForegroundColor Cyan

$ourObjectives = @{
    "49184457-0a0d-4e9c-8d57-c8408e1c3f57" = "Finance"        # Achieve top-quartile financial reporting accuracy and ESG transparency
    "eba5dcf3-9b41-4a0d-b07a-2276f2ab7992" = "Customer"       # Deliver a unified, trusted Customer 360
    "5191f3b3-78af-4003-a331-6f04ec3aed2d" = "HR"             # Build a data-driven, equitable, high-performing workforce
    "c15247c3-0b1f-43f8-9df5-7f6d943542d1" = "Operations"     # Improve plant uptime, safety, and supply-chain visibility
    "59d2e253-330c-409e-9452-023a6a44bc31" = "Technology"     # Establish a trusted, governed, scalable enterprise data platform
}

$krUpdated = 0
foreach ($objId in $ourObjectives.Keys) {
    $lob = $ourObjectives[$objId]
    $kr = Invoke-RestMethod -Uri "$dgBase/objectives/$objId/keyResults$api" -Headers $headers -Method Get
    foreach ($k in $kr.value) {
        # Synthesize realistic mid-Q2 progress: 35-65% of goal, OnTrack/AtRisk
        $pct = Get-Random -Minimum 35 -Maximum 70
        $newProgress = [math]::Round($k.goal * ($pct / 100.0), 2)
        $newStatus = if ($pct -ge 60) { "OnTrack" } elseif ($pct -ge 45) { "AtRisk" } else { "Behind" }
        $body = @{
            id         = $k.id
            definition = $k.definition
            domainId   = $k.domainId
            progress   = $newProgress
            goal       = $k.goal
            max        = $k.max
            status     = $newStatus
        } | ConvertTo-Json
        try {
            $r = Invoke-RestMethod -Uri "$dgBase/objectives/$objId/keyResults/$($k.id)$api" -Headers $headers -Method Put -Body $body
            Write-Host "  ✓ [$lob] $($k.definition.Substring(0,[Math]::Min(60,$k.definition.Length))) → $newProgress / $($k.goal) ($newStatus)"
            $krUpdated++
        } catch {
            $msg = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
            Write-Host "  ✗ [$lob] $($k.definition) :: $msg" -ForegroundColor Red
        }
    }
}
$summary["Sprint C.1 — KR progress updated"] = "$krUpdated KRs"

# ============================================================
# Final report
# ============================================================
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Green
$summary.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-40} {1}" -f $_.Key, $_.Value) }
