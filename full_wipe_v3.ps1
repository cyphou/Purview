# =============================================================================
# FULL WIPE & REDEPLOY v3 — Unified Catalog + Atlas API fallback
# =============================================================================
# Strategy:
#   - Unified Catalog objects: PUT status=Draft (with id!) → DELETE
#   - Old Atlas objects (403 on Unified Catalog): DELETE via Atlas API
#   - Data Products: same dual approach
#   - Order: Terms → Data Products → Domains (children first)
# =============================================================================

$ErrorActionPreference = "Continue"
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$base    = "https://pdedemopurv.purview.azure.com"
$api     = "api-version=2026-03-20-preview"
$atlas   = "$base/catalog/api/atlas/v2"
$myOid   = "0738cec4-3dd2-4d28-86bc-9585d85eb511"

# ── Delete a term: try Unified Catalog (unpublish+delete), fallback to Atlas ──
function Remove-Term($t, $domainId) {
    $tid = $t.id; $tname = $t.name
    # Approach 1: Unified Catalog — unpublish then delete
    if ($t.status -ne "Draft") {
        $body = @{ id = $tid; status = "Draft"; name = $tname; description = "."; domain = $domainId } | ConvertTo-Json
        $r = Invoke-WebRequest "$base/datagovernance/catalog/terms/${tid}?$api" -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -eq 403) {
            # Fallback to Atlas API
            $ra = Invoke-WebRequest "$atlas/entity/guid/${tid}?api-version=2022-08-01-preview" -Headers $headers -Method DELETE -SkipHttpErrorCheck
            if ($ra.StatusCode -eq 200) { Write-Host "    DEL $tname — OK (Atlas)" -ForegroundColor Green; return $true }
            else { Write-Host "    DEL $tname — FAIL (Atlas $($ra.StatusCode))" -ForegroundColor Red; return $false }
        }
        if ($r.StatusCode -ne 200) { Write-Host "    UNPUBLISH $tname — FAIL ($($r.StatusCode))" -ForegroundColor Red; return $false }
    }
    $r2 = Invoke-WebRequest "$base/datagovernance/catalog/terms/${tid}?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
    if ($r2.StatusCode -in 200,204) { Write-Host "    DEL $tname — OK" -ForegroundColor Green; return $true }
    else { Write-Host "    DEL $tname — FAIL ($($r2.StatusCode))" -ForegroundColor Red; return $false }
}

# ── Delete a domain: try Unified Catalog (unpublish+delete), fallback to Atlas ──
function Remove-Domain($d) {
    $did = $d.id; $dname = $d.name
    # Approach 1: PUT status=Draft (must include id in body!)
    $body = @{ id = $did; status = "Draft"; name = $dname; type = $d.type; description = if($d.description){"$($d.description)"}else{"."} }
    if ($d.parentId) { $body["parentId"] = $d.parentId }
    $json = $body | ConvertTo-Json -Depth 3
    $r = Invoke-WebRequest "$base/datagovernance/catalog/businessdomains/${did}?$api" -Headers $headers -Method PUT -Body $json -SkipHttpErrorCheck
    if ($r.StatusCode -eq 403) {
        # Fallback to Atlas API
        $ra = Invoke-WebRequest "$atlas/entity/guid/${did}?api-version=2022-08-01-preview" -Headers $headers -Method DELETE -SkipHttpErrorCheck
        if ($ra.StatusCode -eq 200) { Write-Host "  DEL $dname — OK (Atlas)" -ForegroundColor Green; return $true }
        else { Write-Host "  DEL $dname — FAIL (Atlas $($ra.StatusCode))" -ForegroundColor Red; return $false }
    }
    if ($r.StatusCode -ne 200) { Write-Host "  UNPUBLISH $dname — FAIL ($($r.StatusCode) $($r.Content))" -ForegroundColor Red; return $false }
    # DELETE after unpublish
    $r2 = Invoke-WebRequest "$base/datagovernance/catalog/businessdomains/${did}?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
    if ($r2.StatusCode -in 200,204) { Write-Host "  DEL $dname — OK" -ForegroundColor Green; return $true }
    else { Write-Host "  DEL $dname — FAIL ($($r2.StatusCode))" -ForegroundColor Red; return $false }
}

# ── Delete a data product: try Unified Catalog, fallback to Atlas ──
function Remove-DataProduct($dp) {
    $dpid = $dp.id; $dpname = $dp.name
    # Try unpublish
    if ($dp.status -ne "Draft") {
        $body = @{ id = $dpid; status = "Draft"; name = $dpname; type = $dp.type; domain = $dp.domain; description = "." } | ConvertTo-Json -Depth 3
        $r = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts/${dpid}?$api" -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -eq 403) {
            $ra = Invoke-WebRequest "$atlas/entity/guid/${dpid}?api-version=2022-08-01-preview" -Headers $headers -Method DELETE -SkipHttpErrorCheck
            if ($ra.StatusCode -eq 200) { Write-Host "  DEL DP '$dpname' — OK (Atlas)" -ForegroundColor Green; return $true }
            else { Write-Host "  DEL DP '$dpname' — FAIL (Atlas $($ra.StatusCode))" -ForegroundColor Red; return $false }
        }
        if ($r.StatusCode -ne 200) { Write-Host "  UNPUBLISH DP '$dpname' — FAIL ($($r.StatusCode))" -ForegroundColor Red; return $false }
    }
    $r2 = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts/${dpid}?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
    if ($r2.StatusCode -in 200,204) { Write-Host "  DEL DP '$dpname' — OK" -ForegroundColor Green; return $true }
    else { Write-Host "  DEL DP '$dpname' — FAIL ($($r2.StatusCode))" -ForegroundColor Red; return $false }
}

# ======================================================================
#  PHASE 1 — DELETE ALL TERMS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 1 — DELETE ALL TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$doms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
Write-Host "Domains: $($doms.Count)"

$tOk = 0; $tFail = 0
foreach ($d in $doms) {
    try { $terms = (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=200" -Headers $headers -ErrorAction Stop).value } catch { continue }
    if (-not $terms -or $terms.Count -eq 0) { continue }
    Write-Host "  Domain '$($d.name)' — $($terms.Count) terms"
    foreach ($t in $terms) {
        if (Remove-Term $t $d.id) { $tOk++ } else { $tFail++ }
    }
}
Write-Host "`nTerms: $tOk deleted / $tFail failed" -ForegroundColor $(if($tFail -eq 0){"Green"}else{"Yellow"})

# ======================================================================
#  PHASE 2 — DELETE ALL DATA PRODUCTS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 2 — DELETE ALL DATA PRODUCTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$dps = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?$api" -Headers $headers).value
Write-Host "Data Products: $($dps.Count)"
$dpOk = 0; $dpFail = 0
foreach ($dp in $dps) {
    if (Remove-DataProduct $dp) { $dpOk++ } else { $dpFail++ }
}
Write-Host "`nData Products: $dpOk deleted / $dpFail failed" -ForegroundColor $(if($dpFail -eq 0){"Green"}else{"Yellow"})

# ======================================================================
#  PHASE 3 — DELETE ALL DOMAINS (children first)
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 3 — DELETE ALL DOMAINS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Refresh after term/DP deletions
$doms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
# 3-level delete: grandchildren → children → parents
$grandchildren = @($doms | Where-Object { $_.parentId -and ($doms | Where-Object { $_.id -eq $doms[0].parentId }).parentId })
$children = @($doms | Where-Object { $_.parentId })
$parents  = @($doms | Where-Object { -not $_.parentId })
# Simple approach: sort by depth (deepest first) — domains with parentId whose parent also has parentId
$sorted = @()
# Pass 1: leaf domains (parentId set, parent also has parentId)
foreach ($d in $doms) {
    if ($d.parentId) {
        $parent = $doms | Where-Object { $_.id -eq $d.parentId }
        if ($parent -and $parent.parentId) { $sorted += $d }
    }
}
# Pass 2: mid-level domains (parentId set, parent has no parentId)
foreach ($d in $doms) {
    if ($d.parentId -and $d -notin $sorted) { $sorted += $d }
}
# Pass 3: root domains (no parentId)
foreach ($d in $doms) { if (-not $d.parentId) { $sorted += $d } }

$dOk = 0; $dFail = 0
foreach ($d in $sorted) {
    if (Remove-Domain $d) { $dOk++ } else { $dFail++ }
}
Write-Host "`nDomains: $dOk deleted / $dFail failed" -ForegroundColor $(if($dFail -eq 0){"Green"}else{"Yellow"})

# Verify
$remaining = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
Write-Host "Remaining domains: $($remaining.Count)" -ForegroundColor $(if($remaining.Count -eq 0){"Green"}else{"Red"})
if ($remaining.Count -gt 0) {
    $remaining | ForEach-Object { Write-Host "  STILL: $($_.name) [$($_.type)]" -ForegroundColor Red }
}
$remainDPs = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?$api" -Headers $headers).value
Write-Host "Remaining data products: $($remainDPs.Count)" -ForegroundColor $(if($remainDPs.Count -eq 0){"Green"}else{"Red"})

# ======================================================================
#  PHASE 4 — CREATE DOMAIN HIERARCHY
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 4 — CREATE DOMAIN HIERARCHY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$users = Get-Content "$PSScriptRoot\demo_users.json" | ConvertFrom-Json

function New-Domain($name, $desc, $type, $color, $parentId) {
    $id = [guid]::NewGuid().ToString()
    $body = @{
        id = $id; name = $name; description = $desc
        status = "Published"; type = $type; isRestricted = $false
        thumbnail = @{ color = $color }
        contacts = @{ owner = @(@{ id = $myOid; description = "Admin" }) }
        domains = @(); managedAttributes = @()
    }
    if ($parentId) { $body["parentId"] = $parentId }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
        Write-Host "  + $name [$type] — OK (id=$($r.id))" -ForegroundColor Green
        return $r.id
    } catch {
        Write-Host "  + $name [$type] — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        return $null
    }
}

# L1: Root
$rootId = New-Domain "TTE Group" "Root governance domain for TTE industrial group — energy, chemicals, and services." "FunctionalUnit" "#1B2631" $null

# L2: Lines of Business
$finLobId  = New-Domain "Finance and ESG"             "Financial reporting, ESG metrics, CSRD compliance, treasury and accounting." "LineOfBusiness" "#2E86C1" $rootId
$custLobId = New-Domain "Customer and Sales"          "Customer 360, CRM, sales pipeline, B2B/B2C segmentation."                  "LineOfBusiness" "#27AE60" $rootId
$hrLobId   = New-Domain "HR and People"               "Workforce analytics, talent management, payroll, engagement."              "LineOfBusiness" "#8E44AD" $rootId
$opsLobId  = New-Domain "Operations and Industrial"   "Operational performance, industrial assets, supply chain, maintenance."    "LineOfBusiness" "#E67E22" $rootId
$techLobId = New-Domain "Technology and Data Platform" "Data platform health, data quality, infrastructure, BI & analytics."      "LineOfBusiness" "#2C3E50" $rootId

# L3: Data Domains
$finAcct   = New-Domain "Accounting and Reporting"   "General ledger, P&L, balance sheet, statutory and management reporting."       "DataDomain" "#3498DB" $finLobId
$finTreas  = New-Domain "Treasury and Risk"          "Cash management, FX exposure, financial risk, credit and liquidity."            "DataDomain" "#5DADE2" $finLobId
$finEsg    = New-Domain "ESG and Sustainability"     "Carbon footprint, CSRD compliance, ESG scores, environmental KPIs."            "DataDomain" "#1ABC9C" $finLobId
$custCrm   = New-Domain "CRM and Customer Data"     "Customer master, contact management, segmentation, consent and preferences."   "DataDomain" "#2ECC71" $custLobId
$custComm  = New-Domain "Commercial Analytics"       "Sales pipeline, forecasting, pricing, market share, channel performance."      "DataDomain" "#58D68D" $custLobId
$hrTalent  = New-Domain "Talent Management"          "Recruitment, onboarding, career development, succession planning."             "DataDomain" "#9B59B6" $hrLobId
$hrWork    = New-Domain "Workforce Analytics"        "Headcount, turnover, absenteeism, compensation benchmarking."                  "DataDomain" "#AF7AC5" $hrLobId
$opsAsset  = New-Domain "Industrial Assets"          "Equipment registry, maintenance, inspections, corrosion, predictive analytics." "DataDomain" "#E74C3C" $opsLobId
$opsSC     = New-Domain "Supply Chain and Logistics" "Procurement, inventory, warehousing, transport, supplier performance."         "DataDomain" "#F39C12" $opsLobId
$techDE    = New-Domain "Data Engineering"           "Pipelines, data quality, lineage, schema management, ingestion."               "DataDomain" "#34495E" $techLobId
$techBI    = New-Domain "BI and Analytics"            "Reports, dashboards, usage analytics, self-service BI governance."             "DataDomain" "#566573" $techLobId

# ======================================================================
#  PHASE 5 — CREATE GLOSSARY TERMS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 5 — CREATE GLOSSARY TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$contactMap = @{}
if ($finAcct)  { $contactMap[$finAcct]  = @{ owner = $users.'financeowner';   steward = $users.'financesteward' } }
if ($finTreas) { $contactMap[$finTreas] = @{ owner = $users.'financeowner';   steward = $users.'financesteward' } }
if ($finEsg)   { $contactMap[$finEsg]   = @{ owner = $users.'financeowner';   steward = $users.'financesteward' } }
if ($custCrm)  { $contactMap[$custCrm]  = @{ owner = $users.'customer.owner'; steward = $users.'customer.steward' } }
if ($custComm) { $contactMap[$custComm] = @{ owner = $users.'customer.owner'; steward = $users.'customer.steward' } }
if ($hrTalent) { $contactMap[$hrTalent] = @{ owner = $users.'hr.owner';       steward = $users.'hr.steward' } }
if ($hrWork)   { $contactMap[$hrWork]   = @{ owner = $users.'hr.owner';       steward = $users.'hr.steward' } }
if ($opsAsset) { $contactMap[$opsAsset] = @{ owner = $users.'ops.owner';      steward = $users.'ops.steward' } }
if ($opsSC)    { $contactMap[$opsSC]    = @{ owner = $users.'ops.owner';      steward = $users.'ops.steward' } }
if ($techDE)   { $contactMap[$techDE]   = @{ owner = $users.'tech.owner';     steward = $users.'tech.steward' } }
if ($techBI)   { $contactMap[$techBI]   = @{ owner = $users.'tech.owner';     steward = $users.'tech.steward' } }

function New-Term($name, $desc, $domainId, $acronyms) {
    if (-not $domainId) { Write-Host "    SKIP $name — no domain" -ForegroundColor DarkYellow; return $null }
    $c = $contactMap[$domainId]
    $body = @{
        id = [guid]::NewGuid().ToString(); name = $name; description = $desc
        status = "Published"; domain = $domainId
        contacts = @{
            owner  = @( @{ id = $c.owner;    description = "Data Owner" } )
            expert = @( @{ id = $c.steward;  description = "Data Steward" },
                        @{ id = $users.'cdo'; description = "Chief Data Officer" } )
        }
    }
    if ($acronyms) { $body["acronyms"] = $acronyms }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod "$base/datagovernance/catalog/terms?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
        Write-Host "    + $name — OK" -ForegroundColor Green
        return $r.id
    } catch {
        Write-Host "    + $name — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        return $null
    }
}

# ── Accounting and Reporting ──
Write-Host "`n  Accounting and Reporting" -ForegroundColor Yellow
New-Term "Revenue"              "Total income generated from business activities before expenses."                          $finAcct $null
New-Term "EBITDA"               "Earnings Before Interest, Taxes, Depreciation, and Amortization."                         $finAcct @("EBITDA")
New-Term "Net Income"           "Total profit after all expenses, taxes and costs have been deducted from revenue."         $finAcct $null
New-Term "Cost Center"          "Organizational unit that incurs costs but does not directly generate revenue."             $finAcct $null
New-Term "Budget Variance"      "Difference between budgeted and actual financial performance."                             $finAcct $null
New-Term "Chart of Accounts"    "Structured list of all accounts used in the general ledger."                              $finAcct @("CoA")
New-Term "Intercompany"         "Transactions between legal entities within the same corporate group."                     $finAcct @("IC")

# ── Treasury and Risk ──
Write-Host "  Treasury and Risk" -ForegroundColor Yellow
New-Term "Cash Position"        "Current cash and cash equivalents available across all bank accounts."                     $finTreas $null
New-Term "FX Exposure"          "Financial risk arising from fluctuations in foreign exchange rates."                       $finTreas @("FX")
New-Term "Credit Rating"        "Assessment of creditworthiness of a counterparty or instrument."                          $finTreas $null
New-Term "Value at Risk"        "Statistical measure of the maximum potential loss over a given time horizon."             $finTreas @("VaR")

# ── ESG and Sustainability ──
Write-Host "  ESG and Sustainability" -ForegroundColor Yellow
New-Term "Carbon Footprint"     "Total greenhouse gas emissions caused directly or indirectly."                            $finEsg $null
New-Term "ESG Score"            "Composite rating measuring Environmental, Social, and Governance performance."            $finEsg @("ESG")
New-Term "CSRD Compliance"      "Adherence to Corporate Sustainability Reporting Directive requirements."                  $finEsg @("CSRD")
New-Term "Scope 1 Emissions"    "Direct GHG emissions from owned or controlled sources."                                  $finEsg $null
New-Term "Scope 2 Emissions"    "Indirect GHG emissions from purchased electricity, steam, heating, and cooling."         $finEsg $null
New-Term "Water Intensity"      "Volume of water consumed per unit of production or revenue."                              $finEsg $null

# ── CRM and Customer Data ──
Write-Host "  CRM and Customer Data" -ForegroundColor Yellow
New-Term "Customer ID"          "Unique identifier assigned to each customer across all systems."                           $custCrm $null
New-Term "Customer Lifetime Value" "Predicted net profit from the entire future relationship with a customer."             $custCrm @("CLV")
New-Term "Net Promoter Score"   "Customer loyalty metric based on likelihood to recommend."                                $custCrm @("NPS")
New-Term "Churn Rate"           "Percentage of customers who stop using the product or service in a given period."         $custCrm $null
New-Term "Customer Segment"     "Classification of customers into groups based on shared characteristics."                 $custCrm $null
New-Term "GDPR Consent Status"  "Record of customer consent for data processing under GDPR."                              $custCrm $null

# ── Commercial Analytics ──
Write-Host "  Commercial Analytics" -ForegroundColor Yellow
New-Term "Sales Pipeline"       "Total value and stage distribution of active sales opportunities."                        $custComm $null
New-Term "Lead Conversion Rate" "Percentage of leads that convert to paying customers."                                    $custComm $null
New-Term "Average Order Value"  "Mean monetary value of customer orders over a given period."                              $custComm @("AOV")
New-Term "Win Rate"             "Percentage of sales opportunities that result in a closed deal."                          $custComm $null
New-Term "Market Share"         "Percentage of total market revenue captured by the company."                              $custComm $null

# ── Talent Management ──
Write-Host "  Talent Management" -ForegroundColor Yellow
New-Term "Employee ID"          "Unique identifier assigned to each employee across HR systems."                           $hrTalent $null
New-Term "Time to Hire"         "Number of days from job posting to accepted offer."                                       $hrTalent @("TTH")
New-Term "Training Hours"       "Total hours of professional development per employee per year."                           $hrTalent $null
New-Term "Succession Readiness" "Percentage of critical roles with identified and prepared successors."                    $hrTalent $null
New-Term "Engagement Score"     "Composite metric from employee surveys measuring satisfaction and motivation."            $hrTalent $null

# ── Workforce Analytics ──
Write-Host "  Workforce Analytics" -ForegroundColor Yellow
New-Term "Headcount"            "Total number of active employees at a given point in time."                               $hrWork $null
New-Term "Turnover Rate"        "Percentage of employees leaving the organization in a given period."                      $hrWork $null
New-Term "Absenteeism Rate"     "Percentage of scheduled work days lost to unplanned absences."                            $hrWork $null
New-Term "Compensation Band"    "Salary range associated with a job grade or level."                                       $hrWork $null
New-Term "Gender Pay Gap"       "Difference in average earnings between male and female employees."                        $hrWork $null

# ── Industrial Assets ──
Write-Host "  Industrial Assets" -ForegroundColor Yellow
New-Term "Equipment ID"         "Unique identifier for each physical asset in the industrial registry."                    $opsAsset $null
New-Term "OEE"                  "Overall Equipment Effectiveness — availability x performance x quality."                 $opsAsset @("OEE")
New-Term "MTBF"                 "Mean Time Between Failures — average operating time between breakdowns."                 $opsAsset @("MTBF")
New-Term "Downtime"             "Total time equipment is non-operational due to failure or maintenance."                   $opsAsset $null
New-Term "Corrosion Loop"       "Defined group of equipment sharing similar corrosion degradation mechanisms."             $opsAsset $null
New-Term "Safety Incident"      "Any event resulting in injury, illness, or near-miss in the workplace."                  $opsAsset $null
New-Term "Production Yield"     "Ratio of usable output to total input in a manufacturing process."                       $opsAsset $null

# ── Supply Chain and Logistics ──
Write-Host "  Supply Chain and Logistics" -ForegroundColor Yellow
New-Term "Lead Time"            "Time elapsed from order placement to delivery."                                           $opsSC $null
New-Term "Inventory Turnover"   "Number of times inventory is sold and replaced in a given period."                       $opsSC $null
New-Term "On-Time Delivery"     "Percentage of orders delivered by the promised date."                                     $opsSC @("OTD")
New-Term "Supplier Score"       "Composite rating of supplier quality, reliability, and cost-effectiveness."              $opsSC $null
New-Term "Procurement Spend"    "Total expenditure on goods and services from external suppliers."                         $opsSC $null

# ── Data Engineering ──
Write-Host "  Data Engineering" -ForegroundColor Yellow
New-Term "Data Quality Score"   "Composite metric measuring accuracy, completeness, timeliness, and consistency of data." $techDE @("DQS")
New-Term "Data Freshness"       "Time since the most recent data update in a dataset."                                    $techDE $null
New-Term "Pipeline SLA"         "Service Level Agreement for data pipeline execution time and reliability."                $techDE @("SLA")
New-Term "Schema Drift"         "Unplanned changes to data structure detected between pipeline runs."                     $techDE $null
New-Term "Data Lineage"         "End-to-end trace of data origin, transformations, and consumption."                      $techDE $null

# ── BI and Analytics ──
Write-Host "  BI and Analytics" -ForegroundColor Yellow
New-Term "Active Users"         "Number of unique users who accessed reports or dashboards in a given period."             $techBI @("DAU","MAU")
New-Term "Report Adoption Rate" "Percentage of target audience actively using a published report."                        $techBI $null
New-Term "Query Latency"        "Time taken for a query to return results from the analytics engine."                     $techBI $null
New-Term "Self-Service Ratio"   "Percentage of reports created by business users vs. central BI team."                    $techBI $null
New-Term "Refresh Failure Rate" "Percentage of scheduled data refreshes that fail in a given period."                     $techBI $null

# ======================================================================
#  PHASE 6 — VERIFICATION
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 6 — VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$allDoms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
$allDPs  = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?$api" -Headers $headers).value

Write-Host "`nDomain Hierarchy:" -ForegroundColor Green
$roots = $allDoms | Where-Object { -not $_.parentId }
foreach ($root in $roots) {
    Write-Host "  $($root.name) [$($root.type)]" -ForegroundColor White
    $lobs = $allDoms | Where-Object { $_.parentId -eq $root.id }
    foreach ($lob in $lobs) {
        Write-Host "    +-- $($lob.name) [$($lob.type)]" -ForegroundColor White
        $subs = $allDoms | Where-Object { $_.parentId -eq $lob.id }
        foreach ($sub in $subs) {
            $tc = 0
            try { $tc = (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($sub.id)&top=100" -Headers $headers).value.Count } catch {}
            Write-Host "        +-- $($sub.name) ($tc terms)" -ForegroundColor White
        }
    }
}

$totalTerms = 0
foreach ($d in $allDoms) {
    try { $totalTerms += (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=100" -Headers $headers).value.Count } catch {}
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Domains       : $($allDoms.Count)"
Write-Host "  Terms         : $totalTerms"
Write-Host "  Data Products : $($allDPs.Count)"
Write-Host "========================================"
