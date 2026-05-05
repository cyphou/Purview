$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# ============================================================
# 1. GOVERNANCE DOMAINS - try multiple API paths
# ============================================================
Write-Host "=== GOVERNANCE DOMAINS ===" -ForegroundColor Cyan
$domainApis = @(
    "$baseUrl/datagovernance/catalog/domains?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/governance/domains?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/domains?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/atlas/v2/glossary",
    "$baseUrl/governance/domains?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/governance/domains?api-version=2024-03-01-preview",
    "$baseUrl/datagovernance/catalog/domains?api-version=2024-03-01-preview"
)
$domainFound = $false
foreach ($url in $domainApis) {
    try {
        $domains = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        Write-Host "  SUCCESS at: $url" -ForegroundColor Green
        if ($domains.value) {
            $domains.value | ConvertTo-Json -Depth 5 | Write-Host
        } else {
            $domains | ConvertTo-Json -Depth 5 | Write-Host
        }
        $domainFound = $true
        break
    } catch {
        $status = $_.Exception.Response.StatusCode
        Write-Host "  $status at: $url" -ForegroundColor DarkGray
    }
}

# ============================================================
# 2. DATA PRODUCTS - try multiple API paths
# ============================================================
Write-Host "`n=== DATA PRODUCTS ===" -ForegroundColor Cyan
$productApis = @(
    "$baseUrl/datagovernance/catalog/dataproducts?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/governance/dataproducts?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/dataproducts?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/catalog/dataproducts?api-version=2024-03-01-preview"
)
foreach ($url in $productApis) {
    try {
        $products = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        Write-Host "  SUCCESS at: $url" -ForegroundColor Green
        if ($products.value) {
            $products.value | ConvertTo-Json -Depth 5 | Write-Host
        } else {
            $products | ConvertTo-Json -Depth 5 | Write-Host
        }
        break
    } catch {
        $status = $_.Exception.Response.StatusCode
        Write-Host "  $status at: $url" -ForegroundColor DarkGray
    }
}

# ============================================================
# 3. DATA QUALITY
# ============================================================
Write-Host "`n=== DATA QUALITY ===" -ForegroundColor Cyan
$dqApis = @(
    "$baseUrl/datagovernance/catalog/dataquality/rules?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/dataquality/rules?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/dataquality?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/catalog/dataquality/rules?api-version=2024-03-01-preview"
)
foreach ($url in $dqApis) {
    try {
        $dq = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        Write-Host "  SUCCESS at: $url" -ForegroundColor Green
        if ($dq.value) {
            $dq.value | ConvertTo-Json -Depth 5 | Write-Host
        } else {
            $dq | ConvertTo-Json -Depth 5 | Write-Host
        }
        break
    } catch {
        $status = $_.Exception.Response.StatusCode
        Write-Host "  $status at: $url" -ForegroundColor DarkGray
    }
}

# ============================================================
# 4. BUSINESS CONTEXT / OKRs
# ============================================================
Write-Host "`n=== BUSINESS CONTEXT / OKRs ===" -ForegroundColor Cyan
$okrApis = @(
    "$baseUrl/datagovernance/catalog/objectives?api-version=2023-10-01-preview",
    "$baseUrl/catalog/api/governance/objectives?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/objectives?api-version=2023-10-01-preview",
    "$baseUrl/datagovernance/catalog/objectives?api-version=2024-03-01-preview"
)
foreach ($url in $okrApis) {
    try {
        $okrs = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        Write-Host "  SUCCESS at: $url" -ForegroundColor Green
        if ($okrs.value) {
            $okrs.value | ConvertTo-Json -Depth 5 | Write-Host
        } else {
            $okrs | ConvertTo-Json -Depth 5 | Write-Host
        }
        break
    } catch {
        $status = $_.Exception.Response.StatusCode
        Write-Host "  $status at: $url" -ForegroundColor DarkGray
    }
}

# ============================================================
# 5. Try with purview.azure.com scope (the new unified governance)
# ============================================================
Write-Host "`n=== TRYING WITH purview.azure.com RESOURCE ===" -ForegroundColor Cyan
try {
    $token3 = (az account get-access-token --resource "https://purview.azure.com" --query accessToken -o tsv 2>$null)
    if ($token3) {
        $headers3 = @{ "Authorization" = "Bearer $token3"; "Content-Type" = "application/json" }
        Write-Host "  Got token for purview.azure.com scope ($($token3.Length) chars)" -ForegroundColor Yellow
        
        $govUrls = @(
            "https://api.purview-service.microsoft.com/governance/domains?api-version=2023-10-01-preview",
            "https://api.purview-service.microsoft.com/datagovernance/domains?api-version=2023-10-01-preview",
            "$baseUrl/datagovernance/catalog/domains?api-version=2023-10-01-preview"
        )
        foreach ($url in $govUrls) {
            try {
                $result = Invoke-RestMethod -Uri $url -Headers $headers3 -ErrorAction Stop
                Write-Host "  SUCCESS at: $url" -ForegroundColor Green
                $result | ConvertTo-Json -Depth 5 | Write-Host
                break
            } catch {
                $status = $_.Exception.Response.StatusCode
                Write-Host "  $status at: $url" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  Could not get token for purview.azure.com" -ForegroundColor Red
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# ============================================================
# 6. Refresh catalog search with facets  
# ============================================================
Write-Host "`n=== REFRESHED CATALOG FACETS ===" -ForegroundColor Cyan
try {
    $facetBody = '{"keywords":"*","limit":1,"facets":[{"facet":"entityType","count":100},{"facet":"classification","count":50},{"facet":"collectionId","count":50},{"facet":"glossaryType","count":20},{"facet":"term","count":50}]}'
    $fr = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $facetBody
    Write-Host "Total assets: $($fr.'@search.count')"
    
    Write-Host "`n  Entity Types:" -ForegroundColor Yellow
    $fr.'@search.facets'.entityType | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
    
    if ($fr.'@search.facets'.term) {
        Write-Host "`n  Terms:" -ForegroundColor Yellow
        $fr.'@search.facets'.term | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
    }
    
    Write-Host "`n  Collections:" -ForegroundColor Yellow
    $fr.'@search.facets'.collectionId | ForEach-Object { Write-Host "    $($_.value): $($_.count)" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# ============================================================
# 7. Glossary refresh
# ============================================================
Write-Host "`n=== GLOSSARY REFRESH ===" -ForegroundColor Cyan
try {
    $glossaries = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary?api-version=2022-03-01-preview" -Headers $headers
    if ($glossaries -is [array]) {
        foreach ($g in $glossaries) {
            Write-Host "  Glossary: $($g.name) | Terms: $($g.terms.Count)" -ForegroundColor Yellow
            if ($g.terms) { $g.terms | ForEach-Object { Write-Host "    - $($_.displayText)" } }
        }
    } else {
        Write-Host "  Glossary: $($glossaries.name) | Terms: $($glossaries.terms.Count)" -ForegroundColor Yellow
        if ($glossaries.terms) { $glossaries.terms | ForEach-Object { Write-Host "    - $($_.displayText)" } }
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# ============================================================
# 8. Data sources & scans (retry)
# ============================================================
Write-Host "`n=== DATA SOURCES ===" -ForegroundColor Cyan
try {
    $sources = Invoke-RestMethod -Uri "$baseUrl/scan/datasources?api-version=2022-07-01-preview" -Headers $headers
    $sources.value | ForEach-Object { 
        Write-Host "  - $($_.name) [Kind: $($_.kind)]" -ForegroundColor Yellow
        # Get scans for each source
        try {
            $scans = Invoke-RestMethod -Uri "$baseUrl/scan/datasources/$($_.name)/scans?api-version=2022-07-01-preview" -Headers $headers
            if ($scans.value) {
                $scans.value | ForEach-Object { Write-Host "      Scan: $($_.name) [Kind: $($_.kind)]" }
            }
        } catch {}
    }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`n=== DONE ===" -ForegroundColor Green
