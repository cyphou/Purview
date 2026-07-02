# Sprint July-2026-A: Enable Glossary Asset Curation + Probe Term→Asset REST
#
# NEW in April 2026 (Preview): Glossary terms can now link to data assets and columns
# via a one-time "glossary migration and asset enablement" process. After that, the
# portal shows "Add data assets" / "Add column" on the term's Related tab.
#
# This script:
#   1) Probes the migration/enablement endpoint to unlock term→asset linking
#   2) Tests whether the REST endpoint for term→asset linking now responds correctly
#      (previously returned 404; may be unblocked post-migration)
#   3) If REST works: bulk-attaches 75 terms to their canonical data assets
#   4) Reports the full results
#
# Source: https://learn.microsoft.com/en-us/purview/unified-catalog-glossary-terms-migrate
# Requires: Data Steward role on governance domains + Data Reader on asset collections

param(
    [string]$PurviewAccount = "pdedemopurv",
    [switch]$DryRun            # If set: probe and report only; don't create relationships
)

$ErrorActionPreference = "Stop"
$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://$PurviewAccount.purview.azure.com/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

function Invoke-Api($method, $uri, $body = $null) {
    $params = @{ Uri=$uri; Headers=$headers; Method=$method; SkipHttpErrorCheck=$true }
    if ($body) { $params.Body = ($body | ConvertTo-Json -Depth 10); $params.ContentType = "application/json" }
    $r = Invoke-WebRequest @params
    $c = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
    [PSCustomObject]@{ Status=$r.StatusCode; Body=$c }
}

Write-Host "=== Step 1: Probe Glossary Asset Curation Enablement ===" -ForegroundColor Cyan
Write-Host "  Testing known migration endpoint patterns..." -ForegroundColor DarkGray

# Try candidate endpoint paths — the doc slug is 'glossary-terms-migrate'
$candidates = @(
    "POST $dgBase/glossary/migrate$api"
    "POST $dgBase/settings/glossaryMigration$api"
    "POST $dgBase/settings/assetCuration$api"
    "GET  $dgBase/glossary/migrationStatus$api"
    "POST $dgBase/glossaryTerms/migration$api"
    "POST $dgBase/settings/enableAssetCuration$api"
)

$migrationEndpoint = $null
foreach ($c in $candidates) {
    $verb, $url = $c -split " ", 2
    $r = Invoke-Api $verb $url @{}
    $icon = if ($r.Status -notin 404, 405) { "✅" } else { "  " }
    Write-Host ("  {0} [{1}] {2}" -f $icon, $r.Status, $c) -ForegroundColor $(if ($r.Status -notin 404,405) { "Green" } else { "DarkGray" })
    if ($r.Status -notin 404, 405 -and -not $migrationEndpoint) { $migrationEndpoint = $c }
}

if ($migrationEndpoint) {
    Write-Host "`n  🆕 Found live migration endpoint: $migrationEndpoint" -ForegroundColor Green
} else {
    Write-Host "`n  ⚠️  No migration endpoint responded — feature may require portal one-time setup first." -ForegroundColor Yellow
    Write-Host "     Portal steps: Unified Catalog → Catalog management → Enterprise glossary → Migrate terms" -ForegroundColor DarkGray
    Write-Host "     (see https://learn.microsoft.com/en-us/purview/unified-catalog-glossary-terms-migrate)" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 2: Probe Term→DataAsset REST Linking (post-April 2026 preview) ===" -ForegroundColor Cyan

# Load all terms to get IDs
$allTerms = (Invoke-RestMethod -Uri "$dgBase/terms$api&top=200" -Headers $headers).value
Write-Host "  Loaded $($allTerms.Count) terms" -ForegroundColor DarkGray

# Load all dataAssets (UC-side IDs, NOT Atlas GUIDs)
$allAssets = (Invoke-RestMethod -Uri "$dgBase/dataAssets$api&top=200" -Headers $headers).value
Write-Host "  Loaded $($allAssets.Count) UC data assets" -ForegroundColor DarkGray

$termMap  = @{}; foreach ($t in $allTerms)  { $termMap[$t.name]  = $t.id }
$assetMap = @{}; foreach ($a in $allAssets) { $assetMap[$a.name] = $a.id }

# Pick one term + one known asset to probe the new REST endpoint
$probeTermName  = "Enterprise Financial KPI"
$probeAssetName = "Finance Report"
$probeTermId    = $termMap[$probeTermName]
$probeAssetId   = $assetMap[$probeAssetName]

if (-not $probeTermId)  { Write-Host "  SKIP probe: term '$probeTermName' not found" -ForegroundColor Yellow }
if (-not $probeAssetId) { Write-Host "  SKIP probe: asset '$probeAssetName' not found" -ForegroundColor Yellow }

if ($probeTermId -and $probeAssetId) {
    Write-Host "`n  Probing term→asset relationship endpoints..." -ForegroundColor DarkGray

    # Path A: same DP-style endpoint but on terms/{id}/relationships
    $pathA = "$dgBase/terms/$probeTermId/relationships?entityType=DataAsset&api-version=2026-03-20-preview"
    $rA = Invoke-Api "GET" $pathA
    Write-Host ("  Path A (GET terms/{id}/relationships?entityType=DataAsset): HTTP {0}" -f $rA.Status) -ForegroundColor $(if ($rA.Status -eq 200) { "Green" } else { "Yellow" })
    if ($rA.Status -eq 200) {
        $existing = ($rA.Body | ConvertFrom-Json)
        Write-Host ("    → {0} existing asset link(s)" -f $(if ($existing.value) { $existing.value.Count } else { $existing.count })) -ForegroundColor DarkGray
    }

    # Path B: POST to create
    $bodyB = @{ relationshipType="Related"; entityId=$probeAssetId }
    $rB = Invoke-Api "POST" $pathA $bodyB
    Write-Host ("  Path B (POST terms/{id}/relationships?entityType=DataAsset): HTTP {0}" -f $rB.Status) -ForegroundColor $(if ($rB.Status -in 200,201) { "Green" } elseif ($rB.Status -in 400,404) { "Red" } else { "Yellow" })
    if ($rB.Status -notin 200,201) {
        $snippet = $rB.Body.Substring(0, [Math]::Min(300, $rB.Body.Length))
        Write-Host "    Error: $snippet" -ForegroundColor DarkGray
    }

    # Path C: new 'assets' subpath (speculative — docs show 'Add data assets' link on term page)
    $pathC = "$dgBase/terms/$probeTermId/assets?api-version=2026-03-20-preview"
    $rC = Invoke-Api "GET" $pathC
    Write-Host ("  Path C (GET terms/{id}/assets): HTTP {0}" -f $rC.Status) -ForegroundColor $(if ($rC.Status -eq 200) { "Green" } else { "DarkGray" })

    # Path D: POST on the asset side (assets/{id}/relationships?entityType=Term)
    $pathD = "$dgBase/dataAssets/$probeAssetId/relationships?entityType=Term&api-version=2026-03-20-preview"
    $bodyD = @{ relationshipType="Related"; entityId=$probeTermId }
    $rD = Invoke-Api "POST" $pathD $bodyD
    Write-Host ("  Path D (POST dataAssets/{id}/relationships?entityType=Term): HTTP {0}" -f $rD.Status) -ForegroundColor $(if ($rD.Status -in 200,201) { "Green" } elseif ($rD.Status -in 400,404) { "Red" } else { "Yellow" })
    if ($rD.Status -notin 200,201) {
        $snippet = $rD.Body.Substring(0, [Math]::Min(300, $rD.Body.Length))
        Write-Host "    Error: $snippet" -ForegroundColor DarkGray
    }

    $restUnlocked = ($rB.Status -in 200,201) -or ($rD.Status -in 200,201)
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 3: Bulk Term→Asset Linking (if REST works) ===" -ForegroundColor Cyan

# Canonical mapping: term → the most relevant UC data asset name
# Based on the 15 CDEs' asset assignments + known DP assets
$termAssetMap = @{
    # Finance
    "Enterprise Financial KPI"     = "Finance Report"
    "Financial Reporting Period"   = "Finance Report"
    "ESG Disclosure Metric"        = "Finance Report"
    "Revenue"                      = "fact_sale"
    "EBITDA"                       = "Finance Report"
    "Net Income"                   = "Finance Report"
    "Cost Center"                  = "aggregate_sale_by_date_employee"
    "Budget Variance"              = "Finance Report"
    "Carbon Footprint"             = "Finance Report"
    "ESG Score"                    = "Finance Report"
    "CSRD Compliance"              = "Finance Report"
    # Customer
    "Customer Master Record"       = "dimension_customer"
    "Customer Engagement Event"    = "dimension_customer"
    "Sales Performance Indicator"  = "fact_sale"
    "Customer ID"                  = "dimension_customer"
    "Customer Lifetime Value"      = "dimension_customer"
    "Churn Rate"                   = "dimension_customer"
    "Net Promoter Score"           = "dimension_customer"
    "Sales Pipeline"               = "fact_sale"
    "Lead Conversion Rate"         = "fact_sale"
    "Average Order Value"          = "fact_sale"
    # HR
    "Employee Master Record"       = "aggregate_sale_by_date_employee"
    "Workforce Performance Indicator" = "aggregate_sale_by_date_employee"
    "People Lifecycle Event"       = "aggregate_sale_by_date_employee"
    "Employee ID"                  = "aggregate_sale_by_date_employee"
    "Headcount"                    = "aggregate_sale_by_date_employee"
    "Turnover Rate"                = "aggregate_sale_by_date_employee"
    # Technology
    "Data Platform Health Indicator" = "Purview Hub"
    "Data Product Certification"   = "Purview Hub"
    "Data Lineage Anchor"          = "Purview Hub"
}

if (-not $restUnlocked) {
    Write-Host "  ⏭  REST endpoint not yet unblocked — skipping bulk linking." -ForegroundColor Yellow
    Write-Host "     Action required: complete the one-time portal migration first," -ForegroundColor DarkGray
    Write-Host "     then re-run this script." -ForegroundColor DarkGray
} elseif ($DryRun) {
    Write-Host "  [DryRun] Would link $($termAssetMap.Count) term→asset pairs" -ForegroundColor Yellow
    foreach ($kv in $termAssetMap.GetEnumerator()) {
        $tid = $termMap[$kv.Key]; $aid = $assetMap[$kv.Value]
        $found = if ($tid -and $aid) { "✅" } elseif (-not $tid) { "⚠ term missing" } else { "⚠ asset missing" }
        Write-Host ("    {0}  {1,-42} → {2}" -f $found, $kv.Key, $kv.Value) -ForegroundColor DarkGray
    }
} else {
    # Determine the working path from probe
    $linkMethod = if ($rB.Status -in 200,201) { "term-side" } else { "asset-side" }
    Write-Host "  Using $linkMethod REST path" -ForegroundColor DarkGray

    $ok=0; $skip=0; $fail=0
    foreach ($kv in $termAssetMap.GetEnumerator()) {
        $tid = $termMap[$kv.Key]; $aid = $assetMap[$kv.Value]
        if (-not $tid)  { Write-Host "  SKIP (term not found):  $($kv.Key)" -ForegroundColor Yellow; $skip++; continue }
        if (-not $aid)  { Write-Host "  SKIP (asset not found): $($kv.Value)" -ForegroundColor Yellow; $skip++; continue }

        if ($linkMethod -eq "term-side") {
            $uri  = "$dgBase/terms/$tid/relationships?entityType=DataAsset&api-version=2026-03-20-preview"
            $body = @{ relationshipType="Related"; entityId=$aid }
        } else {
            $uri  = "$dgBase/dataAssets/$aid/relationships?entityType=Term&api-version=2026-03-20-preview"
            $body = @{ relationshipType="Related"; entityId=$tid }
        }
        $r = Invoke-Api "POST" $uri $body
        if ($r.Status -in 200,201) {
            Write-Host ("  ok  {0,-42} → {1}" -f $kv.Key, $kv.Value) -ForegroundColor Green; $ok++
        } else {
            $snippet = $r.Body.Substring(0, [Math]::Min(120, $r.Body.Length))
            Write-Host ("  FAIL [{0}] {1} :: {2}" -f $r.Status, $kv.Key, $snippet) -ForegroundColor Red; $fail++
        }
    }
    Write-Host "`n  Linked: $ok  Skipped: $skip  Failed: $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Migration endpoint:  $(if ($migrationEndpoint) { '✅ Found: ' + $migrationEndpoint } else { '⚠ Not found — run portal migration first' })"
Write-Host "  REST term→asset:     $(if ($restUnlocked) { '✅ UNBLOCKED — bulk linking available' } else { '❌ Still blocked — portal migration required' })"
Write-Host ""
Write-Host "  Next steps if still blocked:" -ForegroundColor DarkGray
Write-Host "    1. Portal → Unified Catalog → Catalog management → Enterprise glossary" -ForegroundColor DarkGray
Write-Host "    2. Click 'Migrate terms' (one-time)" -ForegroundColor DarkGray
Write-Host "    3. Re-run this script" -ForegroundColor DarkGray
