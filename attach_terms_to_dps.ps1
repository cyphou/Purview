# Bulk-attach UC glossary terms to the 6 demo Data Products via the
# /dataproducts/{id}/relationships endpoint (entityType=Term).
# Idempotent: existing links return 200 (server dedups).

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api    = "?api-version=2026-03-20-preview"

# Pull all terms (need name -> id map)
$terms = Invoke-RestMethod -Uri "$dgBase/terms$api&top=200" -Headers $headers -Method Get
$termMap = @{}
foreach ($t in $terms.value) { $termMap[$t.name] = $t.id }
Write-Host "Loaded $($termMap.Count) terms" -ForegroundColor Cyan

$DPs = @(
    @{ id="4baeadc4-224c-43be-93a5-819ed2fb9e97"; name="Executive Financial Dashboards";
       terms=@("Enterprise Financial KPI","Financial Reporting Period","Revenue","EBITDA","Net Income","Cost Center","Budget Variance") },
    @{ id="c5e22498-7d09-41b1-a059-3ae5398f7a49"; name="ESG and CSRD Reporting Pack";
       terms=@("ESG Disclosure Metric","Enterprise Financial KPI","Carbon Footprint","ESG Score","CSRD Compliance") },
    @{ id="dd58e805-6ac3-4566-b785-03fec789610c"; name="Customer 360";
       terms=@("Customer Master Record","Customer Engagement Event","Sales Performance Indicator","Customer ID","Customer Lifetime Value","Churn Rate","Net Promoter Score","Sales Pipeline","Lead Conversion Rate","Average Order Value","Market Segment") },
    @{ id="62ad4ddf-1042-49ec-a24e-1181cc737dad"; name="Workforce Analytics Dashboard";
       terms=@("Employee Master Record","Workforce Performance Indicator","People Lifecycle Event","Employee ID","Headcount","Turnover Rate") },
    @{ id="4302076b-110d-4344-85f7-3c41c34d0b82"; name="Operational Performance Hub";
       terms=@("Industrial Asset Identifier","Operational Performance Indicator","Safety and Reliability Event") },
    @{ id="2493e522-afff-4289-8595-1cf20c9db42d"; name="Data Platform Health Monitor";
       terms=@("Data Platform Health Indicator","Data Product Certification","Data Lineage Anchor") }
)

$ok=0; $skip=0; $fail=0
foreach ($dp in $DPs) {
    Write-Host "`n=== $($dp.name) ===" -ForegroundColor Cyan
    foreach ($termName in $dp.terms) {
        $termId = $termMap[$termName]
        if (-not $termId) { Write-Host "  SKIP (term not found): $termName" -ForegroundColor Yellow; $skip++; continue }
        $body = @{ relationshipType="Related"; entityId=$termId } | ConvertTo-Json -Compress
        $uri  = "$dgBase/dataproducts/$($dp.id)/relationships?entityType=Term&api-version=2026-03-20-preview"
        try {
            $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
            if ($r.StatusCode -in 200,201) { Write-Host "  ok  $termName" -ForegroundColor Green; $ok++ }
            elseif ($r.StatusCode -eq 409) { Write-Host "  dup $termName" -ForegroundColor DarkGray; $ok++ }
            else {
                $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
                Write-Host "  FAIL $termName :: HTTP $($r.StatusCode) $c" -ForegroundColor Red; $fail++
            }
        } catch { Write-Host "  ERR $termName :: $($_.Exception.Message)" -ForegroundColor Red; $fail++ }
    }
}

Write-Host "`n========== Linked: $ok  Skipped: $skip  Failed: $fail ==========" -ForegroundColor Green

# Verify by re-reading
Write-Host "`n=== Verification (term count per DP) ===" -ForegroundColor Cyan
foreach ($dp in $DPs) {
    $r = Invoke-RestMethod -Uri "$dgBase/dataproducts/$($dp.id)/relationships?entityType=Term&api-version=2026-03-20-preview" -Headers $headers -Method Get
    Write-Host ("  {0,-40} {1} term(s)" -f $dp.name, $r.count)
}
