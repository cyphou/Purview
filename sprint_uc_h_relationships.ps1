# Sprint UC-H : Wire up the three documented relationship APIs we hadn't used:
#   1. Term -> Term  (Synonym / Related) via /terms/{id}/relationships?entityType=Term
#   2. CDE  -> Term                       via /criticalDataElements/{id}/relationships?entityType=Term
#   3. CDE  -> DataProduct                via /criticalDataElements/{id}/relationships?entityType=DataProduct
#
# Result: populates the "Synonym/Related" rows on every term page and the
# "Critical data elements" panel on each DP / Term.

$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

# Pull all terms and CDEs once for name -> id maps
$terms = Invoke-RestMethod -Uri "$dgBase/terms$api&top=300" -Headers $headers -Method Get
$tMap  = @{}; foreach ($t in $terms.value) { $tMap[$t.name] = $t.id }
$cdes  = Invoke-RestMethod -Uri "$dgBase/criticalDataElements$api&top=200" -Headers $headers -Method Get
$cMap  = @{}; foreach ($c in $cdes.value) { $cMap[$c.name] = $c.id }

Write-Host "Loaded $($tMap.Count) terms, $($cMap.Count) CDEs" -ForegroundColor Cyan

# ---- helper -------------------------------------------------------------
function Invoke-Rel($parentPath, $entityType, $relType, $targetId) {
    $body = @{ relationshipType = $relType; entityId = $targetId } | ConvertTo-Json -Compress
    $uri  = "$dgBase/$parentPath/relationships?entityType=$entityType&api-version=2026-03-20-preview"
    $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
    $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    return @{ Code = $r.StatusCode; Body = $c }
}

# =========================================================================
# Part 1: Term <-> Term  (Synonym / Related)
# =========================================================================
Write-Host "`n=== Part 1: Term-Term relationships ===" -ForegroundColor Cyan
$pairs = @(
    @{ a="Revenue";                        b="Enterprise Financial KPI";  type="Related" },
    @{ a="EBITDA";                         b="Enterprise Financial KPI";  type="Related" },
    @{ a="Net Income";                     b="Enterprise Financial KPI";  type="Related" },
    @{ a="Carbon Footprint";               b="ESG Disclosure Metric";     type="Related" },
    @{ a="ESG Score";                      b="ESG Disclosure Metric";     type="Related" },
    @{ a="CSRD Compliance";                b="ESG Disclosure Metric";     type="Related" },
    @{ a="Customer Lifetime Value";        b="Customer Master Record";    type="Related" },
    @{ a="Net Promoter Score";             b="Customer Engagement Event"; type="Related" },
    @{ a="Sales Pipeline";                 b="Sales Performance Indicator"; type="Related" },
    @{ a="Lead Conversion Rate";           b="Sales Performance Indicator"; type="Related" },
    @{ a="Average Order Value";            b="Sales Performance Indicator"; type="Related" },
    @{ a="Headcount";                      b="Workforce Performance Indicator"; type="Related" },
    @{ a="Turnover Rate";                  b="Workforce Performance Indicator"; type="Related" },
    @{ a="Employee ID";                    b="Employee Master Record";    type="Related" },
    @{ a="Customer ID";                    b="Customer Master Record";    type="Synonym" },
    @{ a="Customer Lifetime Value";        b="Net Promoter Score";        type="Related" },
    @{ a="Cost Center";                    b="Enterprise Financial KPI";  type="Related" }
)
$ok=0; $skip=0; $fail=0
foreach ($p in $pairs) {
    $aId = $tMap[$p.a]; $bId = $tMap[$p.b]
    if (-not $aId -or -not $bId) {
        Write-Host "  SKIP missing term: $($p.a) <-> $($p.b)" -ForegroundColor Yellow; $skip++; continue
    }
    $r = Invoke-Rel "terms/$aId" "Term" $p.type $bId
    if ($r.Code -in 200,201,409) {
        Write-Host "  ok  $($p.a) -[$($p.type)]-> $($p.b)" -ForegroundColor Green; $ok++
    } else {
        Write-Host "  FAIL $($p.a) -> $($p.b) :: HTTP $($r.Code) $($r.Body.Substring(0,[Math]::Min(150,$r.Body.Length)))" -ForegroundColor Red; $fail++
    }
}
Write-Host "Term-Term: $ok ok / $skip skip / $fail fail"

# =========================================================================
# Part 2: CDE -> Term  (each CDE links to its conceptual term)
# =========================================================================
Write-Host "`n=== Part 2: CDE -> Term relationships ===" -ForegroundColor Cyan
$cdeToTerm = @(
    @{ cde="GL Account Number";        term="Cost Center" },
    @{ cde="Fiscal Period";            term="Financial Reporting Period" },
    @{ cde="Reporting Currency";       term="Enterprise Financial KPI" },
    @{ cde="Customer Master ID";       term="Customer Master Record" },
    @{ cde="Email Address (PII)";      term="Customer Engagement Event" },
    @{ cde="Customer Lifetime Value";  term="Customer Lifetime Value" },
    @{ cde="Employee ID";              term="Employee Master Record" },
    @{ cde="Compensation Band";        term="People Lifecycle Event" },
    @{ cde="Cost Center";              term="Cost Center" },
    @{ cde="Equipment ID";             term="Industrial Asset Identifier" },
    @{ cde="Work Order Number";        term="Safety and Reliability Event" },
    @{ cde="Material Number";          term="Industrial Asset Identifier" },
    @{ cde="Asset Sensitivity Label";  term="Data Product Certification" },
    @{ cde="Data Quality Score";       term="Data Platform Health Indicator" },
    @{ cde="Owner Email";              term="Data Lineage Anchor" }
)
$ok=0; $skip=0; $fail=0
foreach ($m in $cdeToTerm) {
    $cId = $cMap[$m.cde]; $tId = $tMap[$m.term]
    if (-not $cId -or -not $tId) {
        Write-Host "  SKIP missing: cde=$($m.cde) term=$($m.term)" -ForegroundColor Yellow; $skip++; continue
    }
    $r = Invoke-Rel "criticalDataElements/$cId" "Term" "Related" $tId
    if ($r.Code -in 200,201,409) {
        Write-Host "  ok  CDE[$($m.cde)] -> Term[$($m.term)]" -ForegroundColor Green; $ok++
    } else {
        Write-Host "  FAIL CDE[$($m.cde)] -> Term[$($m.term)] :: HTTP $($r.Code) $($r.Body.Substring(0,[Math]::Min(150,$r.Body.Length)))" -ForegroundColor Red; $fail++
    }
}
Write-Host "CDE-Term: $ok ok / $skip skip / $fail fail"

# =========================================================================
# Part 3: DataProduct -> CDE  (entityType=CriticalDataElement)
# Note: CDE -> DP direction is not allowed (CDE only accepts Term/DataColumn/CriticalDataColumn).
# =========================================================================
Write-Host "`n=== Part 3: DataProduct -> CDE relationships ===" -ForegroundColor Cyan
$dpExec    = "4baeadc4-224c-43be-93a5-819ed2fb9e97"  # Executive Financial Dashboards
$dpEsg     = "c5e22498-7d09-41b1-a059-3ae5398f7a49"  # ESG and CSRD Reporting Pack
$dpCust    = "dd58e805-6ac3-4566-b785-03fec789610c"  # Customer 360
$dpWork    = "62ad4ddf-1042-49ec-a24e-1181cc737dad"  # Workforce Analytics
$dpOps     = "4302076b-110d-4344-85f7-3c41c34d0b82"  # Operational Performance Hub
$dpHealth  = "2493e522-afff-4289-8595-1cf20c9db42d"  # Data Platform Health Monitor
$cdeToDp = @(
    @{ cde="GL Account Number";       dps=@($dpExec, $dpEsg) },
    @{ cde="Fiscal Period";           dps=@($dpExec, $dpEsg) },
    @{ cde="Reporting Currency";      dps=@($dpExec, $dpEsg) },
    @{ cde="Customer Master ID";      dps=@($dpCust) },
    @{ cde="Email Address (PII)";     dps=@($dpCust) },
    @{ cde="Customer Lifetime Value"; dps=@($dpCust) },
    @{ cde="Employee ID";             dps=@($dpWork) },
    @{ cde="Compensation Band";       dps=@($dpWork) },
    @{ cde="Cost Center";             dps=@($dpWork, $dpExec) },
    @{ cde="Equipment ID";            dps=@($dpOps) },
    @{ cde="Work Order Number";       dps=@($dpOps) },
    @{ cde="Material Number";         dps=@($dpOps) },
    @{ cde="Asset Sensitivity Label"; dps=@($dpHealth) },
    @{ cde="Data Quality Score";      dps=@($dpHealth) },
    @{ cde="Owner Email";             dps=@($dpHealth) }
)
$ok=0; $skip=0; $fail=0
foreach ($m in $cdeToDp) {
    $cId = $cMap[$m.cde]
    if (-not $cId) { Write-Host "  SKIP missing CDE: $($m.cde)" -ForegroundColor Yellow; $skip++; continue }
    foreach ($dpId in $m.dps) {
        $r = Invoke-Rel "dataproducts/$dpId" "CriticalDataElement" "Related" $cId
        if ($r.Code -in 200,201,409) {
            Write-Host "  ok  DP[$dpId] -> CDE[$($m.cde)]" -ForegroundColor Green; $ok++
        } else {
            Write-Host "  FAIL DP[$dpId] -> CDE[$($m.cde)] :: HTTP $($r.Code) $($r.Body.Substring(0,[Math]::Min(150,$r.Body.Length)))" -ForegroundColor Red; $fail++
        }
    }
}
Write-Host "DP-CDE: $ok ok / $skip skip / $fail fail"

Write-Host "`n========== Sprint UC-H complete ==========" -ForegroundColor Green
