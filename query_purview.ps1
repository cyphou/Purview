# Query Microsoft Purview Data Governance - Comprehensive Inventory
$baseUrl = "https://pdedemopurv.purview.azure.com"
$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

$results = @{}

# 1. Collections
Write-Host "=== COLLECTIONS ===" -ForegroundColor Cyan
try {
    $collections = Invoke-RestMethod -Uri "$baseUrl/account/collections?api-version=2019-11-01-preview" -Headers $headers -Method Get
    $results["collections"] = $collections.value
    $collections.value | ForEach-Object { Write-Host "  - $($_.name) ($($_.friendlyName))" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 2. Data Sources (Registered Sources)
Write-Host "`n=== REGISTERED DATA SOURCES ===" -ForegroundColor Cyan
try {
    $sources = Invoke-RestMethod -Uri "$baseUrl/scan/datasources?api-version=2022-07-01-preview" -Headers $headers -Method Get
    $results["datasources"] = $sources.value
    $sources.value | ForEach-Object { Write-Host "  - $($_.name) [Kind: $($_.kind)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 3. Glossary Terms
Write-Host "`n=== GLOSSARY ===" -ForegroundColor Cyan
try {
    $glossaries = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary?api-version=2022-03-01-preview" -Headers $headers -Method Get
    $results["glossaries"] = $glossaries
    if ($glossaries -is [array]) {
        $glossaries | ForEach-Object { 
            Write-Host "  Glossary: $($_.name) - Terms count: $($_.terms.Count)"
            $_.terms | ForEach-Object { Write-Host "    - $($_.displayText)" }
        }
    } else {
        Write-Host "  Glossary: $($glossaries.name) - Terms count: $($glossaries.terms.Count)"
        $glossaries.terms | ForEach-Object { Write-Host "    - $($_.displayText)" }
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 4. Glossary Terms Details
Write-Host "`n=== GLOSSARY TERMS DETAIL ===" -ForegroundColor Cyan
try {
    $terms = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary/terms?api-version=2022-03-01-preview&limit=100" -Headers $headers -Method Get
    $results["glossaryTerms"] = $terms
    $terms | ForEach-Object { Write-Host "  - $($_.name) [Status: $($_.status)] - $($_.shortDescription)" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 5. Search all entities in catalog
Write-Host "`n=== CATALOG ENTITIES (Search) ===" -ForegroundColor Cyan
try {
    $searchBody = @{ keywords = "*"; limit = 100 } | ConvertTo-Json
    $searchResults = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $searchBody
    $results["catalogEntities"] = $searchResults.value
    Write-Host "  Total entities found: $($searchResults.'@search.count')"
    $searchResults.value | ForEach-Object {
        Write-Host "  - $($_.name) [Type: $($_.entityType)] [Source: $($_.qualifiedName)]"
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 6. Classifications (Sensitivity Labels / Data Types)
Write-Host "`n=== CLASSIFICATIONS ===" -ForegroundColor Cyan
try {
    $classificationDefs = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/types/typedefs?type=classification&api-version=2022-03-01-preview" -Headers $headers -Method Get
    $results["classifications"] = $classificationDefs.classificationDefs
    $classificationDefs.classificationDefs | ForEach-Object { Write-Host "  - $($_.name) [Category: $($_.category)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 7. Scan Rules / Scan History
Write-Host "`n=== SCAN RULE SETS ===" -ForegroundColor Cyan
try {
    $scanRules = Invoke-RestMethod -Uri "$baseUrl/scan/scanrulesets?api-version=2022-07-01-preview" -Headers $headers -Method Get
    $results["scanRuleSets"] = $scanRules.value
    $scanRules.value | ForEach-Object { Write-Host "  - $($_.name) [Kind: $($_.kind)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 8. Entity types defined (Custom Types)
Write-Host "`n=== CUSTOM ENTITY TYPES ===" -ForegroundColor Cyan
try {
    $entityDefs = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/types/typedefs?type=entity&api-version=2022-03-01-preview" -Headers $headers -Method Get
    $customTypes = $entityDefs.entityDefs | Where-Object { $_.serviceType -ne $null }
    $results["entityTypes"] = $customTypes
    Write-Host "  Total entity type definitions: $($entityDefs.entityDefs.Count)"
    $entityDefs.entityDefs | Group-Object -Property serviceType | Sort-Object Count -Descending | Select-Object -First 20 | ForEach-Object {
        Write-Host "  - Service: $($_.Name) ($($_.Count) types)"
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 9. Governance Domains (new Purview Data Governance)
Write-Host "`n=== GOVERNANCE DOMAINS ===" -ForegroundColor Cyan
try {
    $domains = Invoke-RestMethod -Uri "$baseUrl/catalog/api/governance/domains?api-version=2023-10-01-preview" -Headers $headers -Method Get
    $results["governanceDomains"] = $domains.value
    if ($domains.value) { $domains.value | ForEach-Object { Write-Host "  - $($_.name) [$($_.status)]" } }
    else { Write-Host "  No governance domains found" }
} catch { Write-Host "  Error (Domains): $($_.Exception.Message)" -ForegroundColor Red }

# 10. Data Products (new Purview Data Governance)
Write-Host "`n=== DATA PRODUCTS ===" -ForegroundColor Cyan
try {
    $products = Invoke-RestMethod -Uri "$baseUrl/catalog/api/governance/dataproducts?api-version=2023-10-01-preview" -Headers $headers -Method Get
    $results["dataProducts"] = $products.value
    if ($products.value) { $products.value | ForEach-Object { Write-Host "  - $($_.name) [$($_.status)]" } }
    else { Write-Host "  No data products found" }
} catch { Write-Host "  Error (Data Products): $($_.Exception.Message)" -ForegroundColor Red }

# 11. Data Quality Rules
Write-Host "`n=== DATA QUALITY RULES ===" -ForegroundColor Cyan
try {
    $dqRules = Invoke-RestMethod -Uri "$baseUrl/catalog/api/dataquality/rules?api-version=2023-10-01-preview" -Headers $headers -Method Get
    $results["dataQualityRules"] = $dqRules.value
    if ($dqRules.value) { $dqRules.value | ForEach-Object { Write-Host "  - $($_.name)" } }
    else { Write-Host "  No data quality rules found" }
} catch { Write-Host "  Error (DQ Rules): $($_.Exception.Message)" -ForegroundColor Red }

# 12. Policies
Write-Host "`n=== POLICIES ===" -ForegroundColor Cyan
try {
    $policies = Invoke-RestMethod -Uri "$baseUrl/policystore/metadataPolicies?api-version=2021-07-01-preview" -Headers $headers -Method Get
    $results["policies"] = $policies.values
    $policies.values | ForEach-Object { Write-Host "  - $($_.name) [Collection: $($_.properties.collection.referenceName)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 13. Managed Private Endpoints
Write-Host "`n=== MANAGED PRIVATE ENDPOINTS ===" -ForegroundColor Cyan
try {
    $mpes = Invoke-RestMethod -Uri "$baseUrl/proxy/managedPrivateEndpoints?api-version=2021-12-01" -Headers $headers -Method Get
    $results["managedPrivateEndpoints"] = $mpes.value
    if ($mpes.value) { $mpes.value | ForEach-Object { Write-Host "  - $($_.name) [$($_.properties.privateLinkResourceId)]" } }
    else { Write-Host "  No managed private endpoints" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 14. Integration Runtimes
Write-Host "`n=== INTEGRATION RUNTIMES ===" -ForegroundColor Cyan
try {
    $irs = Invoke-RestMethod -Uri "$baseUrl/proxy/integrationRuntimes?api-version=2022-03-01-preview" -Headers $headers -Method Get
    $results["integrationRuntimes"] = $irs.value
    $irs.value | ForEach-Object { Write-Host "  - $($_.name) [Kind: $($_.kind)] [State: $($_.properties.state)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 15. Scans per datasource
Write-Host "`n=== SCANS PER DATA SOURCE ===" -ForegroundColor Cyan
if ($results["datasources"]) {
    foreach ($ds in $results["datasources"]) {
        try {
            $scans = Invoke-RestMethod -Uri "$baseUrl/scan/datasources/$($ds.name)/scans?api-version=2022-07-01-preview" -Headers $headers -Method Get
            if ($scans.value) {
                Write-Host "  Source: $($ds.name)" -ForegroundColor Yellow
                $scans.value | ForEach-Object { Write-Host "    - Scan: $($_.name) [Kind: $($_.kind)]" }
            }
        } catch { }
    }
}

# 16. Lineage - Browse root entities
Write-Host "`n=== BROWSE ROOT ENTITIES ===" -ForegroundColor Cyan
try {
    $browseBody = @{ entityType = ""; path = "/"; limit = 50 } | ConvertTo-Json
    $browseResult = Invoke-RestMethod -Uri "$baseUrl/catalog/api/browse?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $browseBody
    $results["browseRoot"] = $browseResult.value
    $browseResult.value | ForEach-Object { Write-Host "  - $($_.name) [$($_.entityType)] owners=$($_.owner.Count)" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# 17. OKRs / Business Context
Write-Host "`n=== BUSINESS CONTEXT (OKRs) ===" -ForegroundColor Cyan
try {
    $okrs = Invoke-RestMethod -Uri "$baseUrl/catalog/api/governance/objectives?api-version=2023-10-01-preview" -Headers $headers -Method Get
    $results["okrs"] = $okrs.value
    if ($okrs.value) { $okrs.value | ForEach-Object { Write-Host "  - $($_.name)" } }
    else { Write-Host "  No OKRs found" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# Export to JSON
$outputPath = "c:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview\purview_inventory.json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding utf8
Write-Host "`n=== INVENTORY EXPORTED to $outputPath ===" -ForegroundColor Green
