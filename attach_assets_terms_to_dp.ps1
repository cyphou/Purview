# Attach UC data assets and glossary terms to UC data products
# Strategy: keyword-match assets/terms to each data product's name + description
$ErrorActionPreference = "Continue"
if (-not $token) { $token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv) }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com"
$api = "?api-version=2026-03-20-preview"

Write-Host "`n=== Load UC Data Products (ours only) ===" -ForegroundColor Cyan
$ourDpNames = @("Convergence B2B","RC Datahub Inspection","Books Analytics &  Forecasting","Executive Financial Dashboards","ESG and CSRD Reporting Pack","Customer 360","Workforce Analytics Dashboard","Operational Performance Hub","Data Platform Health Monitor")
$dps = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts$api" -Headers $headers).value | Where-Object { $_.name -in $ourDpNames }
Write-Host "Loaded $($dps.Count) data products"

Write-Host "`n=== Load UC Data Assets ===" -ForegroundColor Cyan
$das = (Invoke-RestMethod "$base/datagovernance/catalog/dataAssets$api" -Headers $headers).value
Write-Host "Loaded $($das.Count) data assets"

Write-Host "`n=== Load UC Terms ===" -ForegroundColor Cyan
$ucTerms = (Invoke-RestMethod "$base/datagovernance/catalog/terms$api" -Headers $headers).value
Write-Host "Loaded $($ucTerms.Count) UC terms"

# Define keyword mapping per data product (manual curation for high-quality matches)
$dpKeywords = @{
  "Convergence B2B"                  = @{ assets = @("convergence","b2b","wwi","sales pipeline","opportunity"); terms = @("Customer","Revenue","Opportunity","Lead","Sales Pipeline","Contract","KPI") }
  "RC Datahub Inspection"            = @{ assets = @("inspection","quality","equipment","wwi"); terms = @("Asset","Inspection","Equipment","KPI","Data Quality Score") }
  "Books Analytics &  Forecasting"   = @{ assets = @("book","horizon","forecast","sales","fact"); terms = @("Revenue","Forecast","Customer","KPI","Fiscal Year","Currency","Region") }
  "Executive Financial Dashboards"   = @{ assets = @("finance","financial","executive","kpi","fsi","cco","budget"); terms = @("Revenue","Profitability","Budget","Forecast","Finance BI","Return on Investment","KPI","Fiscal Year","Currency") }
  "ESG and CSRD Reporting Pack"      = @{ assets = @("esg","csrd","sustainability","carbon","emission"); terms = @("KPI","Region","Country","Currency","Fiscal Year","Data Quality Score") }
  "Customer 360"                     = @{ assets = @("customer","crm","salesforce","contoso","insights"); terms = @("Customer","Customer Onboarding","Support Ticket","CSAT","Resolution Time","Lead","Opportunity","Win Rate") }
  "Workforce Analytics Dashboard"    = @{ assets = @("hr","employee","workforce","people","headcount"); terms = @("Employee","Region","Country","KPI","Business Unit","Fiscal Year") }
  "Operational Performance Hub"      = @{ assets = @("operation","sap","ramses","radar","equipment","maintenance","inspection","wwi"); terms = @("Asset","Equipment","KPI","Region","Country","Data Quality Score") }
  "Data Platform Health Monitor"     = @{ assets = @("purview","monitor","platform","governance","health","lineage"); terms = @("Data Quality Score","Lineage","Classification","Governance Domain","Data Steward","Data Product","KPI") }
}

Write-Host "`n=== Attach Assets and Terms ===" -ForegroundColor Cyan
$totalAssets = 0; $totalTerms = 0
foreach ($dp in $dps) {
  $cfg = $dpKeywords[$dp.name]
  if (-not $cfg) { Write-Host "  (skip $($dp.name) - no config)" -ForegroundColor DarkGray; continue }
  Write-Host "`n>>> $($dp.name)" -ForegroundColor Yellow

  # Attach data assets
  $matchedDas = @()
  foreach ($kw in $cfg.assets) {
    $matchedDas += $das | Where-Object { $_.name -and $_.name.ToLower().Contains($kw.ToLower()) }
  }
  $matchedDas = $matchedDas | Sort-Object id -Unique | Select-Object -First 8
  foreach ($da in $matchedDas) {
    $body = @{ entityId = $da.id } | ConvertTo-Json -Compress
    $r = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts/$($dp.id)/relationships$api&entityType=DataAsset" -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck
    if ($r.StatusCode -eq 200) { $totalAssets++; Write-Host "  + asset: $($da.name)" -ForegroundColor Green }
    else { Write-Host "  ! asset $($da.name) -> $($r.StatusCode)" -ForegroundColor Yellow }
  }

  # Attach UC terms (using UC term IDs - native UC relationship)
  $matchedTerms = @()
  foreach ($termName in $cfg.terms) {
    $matchedTerms += $ucTerms | Where-Object { $_.name -eq $termName }
  }
  $matchedTerms = $matchedTerms | Sort-Object id -Unique
  foreach ($t in $matchedTerms) {
    $body = @{ entityId = $t.id } | ConvertTo-Json -Compress
    $r = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts/$($dp.id)/relationships$api&entityType=Term" -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck
    if ($r.StatusCode -eq 200) { $totalTerms++; Write-Host "  + term : $($t.name)" -ForegroundColor Cyan }
    else { Write-Host "  ! term $($t.name) -> $($r.StatusCode)" -ForegroundColor Yellow }
  }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Asset attachments: $totalAssets | Term attachments: $totalTerms" -ForegroundColor Green
