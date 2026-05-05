$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

Write-Host "=== GLOSSARY ===" -ForegroundColor Cyan
try {
    $glossaries = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary?api-version=2022-03-01-preview" -Headers $headers
    if ($glossaries -is [array]) {
        foreach ($g in $glossaries) {
            Write-Host "Glossary: $($g.name) | GUID: $($g.guid) | Terms: $($g.terms.Count)" -ForegroundColor Yellow
            if ($g.terms) { $g.terms | ForEach-Object { Write-Host "  - $($_.displayText)" } }
        }
    } else {
        Write-Host "Glossary: $($glossaries.name) | GUID: $($glossaries.guid) | Terms: $($glossaries.terms.Count)" -ForegroundColor Yellow
        if ($glossaries.terms) { $glossaries.terms | ForEach-Object { Write-Host "  - $($_.displayText)" } }
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== CATALOG ENTITIES ===" -ForegroundColor Cyan
try {
    $searchBody = '{"keywords":"*","limit":100}'
    $sr = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $searchBody
    Write-Host "Total entities: $($sr.'@search.count')"
    $sr.value | ForEach-Object { Write-Host "  - $($_.name) [Type: $($_.entityType)] [Collection: $($_.collectionId)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== GLOSSARY TERMS DETAIL ===" -ForegroundColor Cyan
try {
    $terms = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary/terms?api-version=2022-03-01-preview&limit=100" -Headers $headers
    $terms | ForEach-Object { Write-Host "  - $($_.name) [Status: $($_.status)] - $($_.shortDescription)" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== REGISTERED DATA SOURCES ===" -ForegroundColor Cyan
try {
    $sources = Invoke-RestMethod -Uri "$baseUrl/scan/datasources?api-version=2022-07-01-preview" -Headers $headers
    $sources.value | ForEach-Object { Write-Host "  - $($_.name) [Kind: $($_.kind)] [Collection: $($_.properties.collection.referenceName)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# Try new governance APIs with different resource scope
Write-Host "`n=== GOVERNANCE DOMAINS (purview-service scope) ===" -ForegroundColor Cyan
try {
    $token2 = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
    $headers2 = @{ "Authorization" = "Bearer $token2"; "Content-Type" = "application/json" }
    # Try different API paths for new governance experience
    $urls = @(
        "$baseUrl/datagovernance/catalog/domains?api-version=2023-10-01-preview",
        "$baseUrl/catalog/api/governance/domains?api-version=2023-10-01-preview",
        "$baseUrl/datagovernance/domains?api-version=2023-10-01-preview"
    )
    foreach ($url in $urls) {
        try {
            $domains = Invoke-RestMethod -Uri $url -Headers $headers2
            Write-Host "  Success at: $url" -ForegroundColor Green
            $domains.value | ForEach-Object { Write-Host "  - $($_.name)" }
            break
        } catch {
            Write-Host "  Failed at: $url -> $($_.Exception.Response.StatusCode)" -ForegroundColor DarkGray
        }
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# Lineage search
Write-Host "`n=== ENTITY TYPE SUMMARY (by entityType) ===" -ForegroundColor Cyan
try {
    $facetBody = '{"keywords":"*","limit":1,"facets":[{"facet":"entityType","count":50},{"facet":"classification","count":20},{"facet":"collectionId","count":50}]}'
    $facetResult = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $facetBody
    Write-Host "Total assets: $($facetResult.'@search.count')"
    Write-Host "`n  By Entity Type:" -ForegroundColor Yellow
    $facetResult.'@search.facets'.entityType | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
    Write-Host "`n  By Classification:" -ForegroundColor Yellow
    $facetResult.'@search.facets'.classification | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
    Write-Host "`n  By Collection:" -ForegroundColor Yellow
    $facetResult.'@search.facets'.collectionId | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== DONE ===" -ForegroundColor Green
