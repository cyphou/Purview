# Link classic Atlas glossary terms to catalog assets by keyword match
$ErrorActionPreference = "Continue"
$base = "https://pdedemopurv.purview.azure.com"
$apiAtlas = "?api-version=2022-08-01-preview"

if (-not $token) { $token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv) }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

Write-Host "`n=== Step 1: Load all Atlas glossary terms ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"entityType":"AtlasGlossaryTerm"},"limit":150}'
$r = Invoke-RestMethod "$base/catalog/api/search/query$apiAtlas" -Headers $headers -Method Post -Body $body
$terms = $r.value
Write-Host "Loaded $($terms.Count) terms"

Write-Host "`n=== Step 2: Load candidate assets (datasets, reports, tables) ===" -ForegroundColor Cyan
$assetTypes = @("powerbi_dataset","powerbi_report","fabric_lakehouse_table","snowflake_table","mssql_table","postgresql_table","postgresql_view","azure_datalake_gen2_resource_set","dataverse_table")
$allAssets = @()
foreach ($t in $assetTypes) {
    $body = (@{ keywords="*"; filter=@{ entityType=$t }; limit=200 } | ConvertTo-Json -Depth 5 -Compress)
    $r = Invoke-RestMethod "$base/catalog/api/search/query$apiAtlas" -Headers $headers -Method Post -Body $body
    Write-Host "  $t : $($r.value.Count)"
    $allAssets += $r.value
}
Write-Host "Total candidate assets: $($allAssets.Count)"

Write-Host "`n=== Step 3: Match terms to assets by keyword ===" -ForegroundColor Cyan
$assignments = @{}
foreach ($term in $terms) {
    $kw = $term.name.ToLower()
    # Skip very short or generic terms
    if ($kw.Length -lt 3) { continue }
    if ($kw -in @("kpi","sla","oee","nps","arpu","clv","mtbf","mttr","cogs","opex","capex")) {
        # Acronyms — exact match only
        $matches = $allAssets | Where-Object { $_.name -match "\b$([regex]::Escape($term.name))\b" }
    } else {
        $matches = $allAssets | Where-Object { $_.name -and $_.name.ToLower().Contains($kw) }
    }
    if ($matches) {
        $assignments[$term.id] = @{ term=$term; assets=@($matches | Select-Object -First 5) }
    }
}
Write-Host "Terms with matches: $($assignments.Count)"

Write-Host "`n=== Step 4: Apply assignments ===" -ForegroundColor Cyan
$ok = 0; $fail = 0
foreach ($kvp in $assignments.GetEnumerator()) {
    $term = $kvp.Value.term
    $assets = $kvp.Value.assets
    $assignBody = ($assets | ForEach-Object { @{ guid=$_.id; typeName=$_.entityType } }) | ConvertTo-Json -Depth 5 -AsArray
    $r = Invoke-WebRequest "$base/catalog/api/atlas/v2/glossary/terms/$($term.id)/assignedEntities$apiAtlas" -Headers $headers -Method POST -Body $assignBody -SkipHttpErrorCheck
    if ($r.StatusCode -in 204,200) {
        $ok++
        Write-Host ("  + {0,-30} -> {1} assets" -f $term.name, $assets.Count) -ForegroundColor Green
    } else {
        $fail++
        Write-Host ("  ! {0,-30} -> {1}" -f $term.name, $r.StatusCode) -ForegroundColor Yellow
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Terms assigned: $ok | Failed: $fail" -ForegroundColor Green
