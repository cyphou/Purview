# Sprint 4 — Create 6 Production Data Products
# Links each product to its governance domain, line of business, and organization

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Load Sprint 2 GUIDs
$sprint2 = Get-Content "c:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview\sprint2_guids.json" | ConvertFrom-Json

$collectionId = "kxwjyq"  # Domain Global collection

Write-Host "=== STEP 1: Create 6 Production Data Products ===" -ForegroundColor Cyan

$products = @(
    @{
        name = "Executive Financial Dashboards"
        qn = "governance://products/executive-financial-dashboards"
        desc = "Consolidated financial KPIs for C-suite decision making. Includes P&L, Balance Sheet, Cash Flow, and profitability metrics across all business units. Refreshed daily, certified by Finance team. SLA: data no older than 24 hours from source systems."
        domain = "Finance and ESG"
        lob = "Analytics and BI"
        org = "Group"
    },
    @{
        name = "ESG and CSRD Reporting Pack"
        qn = "governance://products/esg-csrd-reporting"
        desc = "Sustainability metrics, carbon footprint (Scope 1/2/3), social and governance scores for CSRD regulatory compliance. Aggregated from industrial operations, energy consumption, and HR data. Refreshed monthly. Audit-ready with full data lineage."
        domain = "Finance and ESG"
        lob = "Corporate Functions"
        org = "Group"
    },
    @{
        name = "Customer 360"
        qn = "governance://products/customer-360"
        desc = "Unified customer view combining CRM, Salesforce, and transactional data. Includes customer demographics, purchase history, support interactions, NPS scores, and lifetime value. Single source of truth for all customer-facing teams. Refreshed daily."
        domain = "Customer and Sales"
        lob = "Digital Services"
        org = "Group"
    },
    @{
        name = "Workforce Analytics"
        qn = "governance://products/workforce-analytics"
        desc = "Employee demographics, attrition trends, engagement scores, compensation benchmarks, and diversity metrics. Supports CHRO and HR Business Partners with data-driven workforce decisions. Monthly refresh with PII protections applied."
        domain = "HR and People"
        lob = "Corporate Functions"
        org = "Group"
    },
    @{
        name = "Operational Performance Hub"
        qn = "governance://products/operational-performance-hub"
        desc = "Equipment OEE, maintenance KPIs (MTBF, MTTR), safety incident tracking, and production throughput across all industrial sites. Sources: SAP work orders, RAMSES events, PI-DA-RC site services. Near-real-time for safety, daily for operations."
        domain = "Operations and Industrial"
        lob = "Industrial Operations"
        org = "RC Division"
    },
    @{
        name = "Data Platform Health"
        qn = "governance://products/data-platform-health"
        desc = "Fabric pipeline execution status, data freshness scores, catalog completeness metrics, and quality rule compliance. Monitors the health of the entire data platform. Enables the CDO and data engineering team to ensure reliable data delivery."
        domain = "Technology and Data Platform"
        lob = "Digital Services"
        org = "Group"
    }
)

$productGuids = @{}

foreach ($p in $products) {
    Write-Host "Creating: $($p.name)..." -NoNewline
    
    # Build relationship references
    $relationships = @{}
    
    # Link to domain
    $domainGuid = $sprint2.domains.($p.domain)
    if ($domainGuid) {
        $relationships["represents"] = @{
            typeName = "Purview_DataDomain"
            guid = $domainGuid
        }
    }
    
    # Link to line of business
    $lobGuid = $sprint2.linesOfBusiness.($p.lob)
    if ($lobGuid) {
        $relationships["isGroupedBy_LineOfBusiness"] = @(
            @{
                typeName = "Purview_LineOfBusiness"
                guid = $lobGuid
            }
        )
    }
    
    # Link to organization
    $orgGuid = $sprint2.organizations.($p.org)
    if ($orgGuid) {
        $relationships["isOfferedBy_Organization"] = @(
            @{
                typeName = "Purview_Organization"
                guid = $orgGuid
            }
        )
    }
    
    $payload = @{
        entity = @{
            typeName = "Purview_Product"
            attributes = @{
                name = $p.name
                qualifiedName = $p.qn
                description = $p.desc
            }
            relationshipAttributes = $relationships
            collectionId = $collectionId
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        $guid = $result.guidAssignments.PSObject.Properties.Value
        if (-not $guid) { $guid = ($result.mutatedEntities.CREATE | Select-Object -First 1).guid }
        if (-not $guid) { $guid = ($result.mutatedEntities.UPDATE | Select-Object -First 1).guid }
        $productGuids[$p.name] = $guid
        Write-Host " OK (GUID: $guid)" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== STEP 2: Clean up test products ===" -ForegroundColor Cyan

# Update test PBIX with a clear "DEPRECATED" marker instead of deleting
$testProductGuid = "2d73c69a-9289-426c-9e33-b7364419f602"
Write-Host "Marking 'test PBIX' as deprecated..." -NoNewline
try {
    $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/${testProductGuid}?api-version=2022-03-01-preview" -Headers $headers
    $entity.entity.attributes.description = "[DEPRECATED] Test product — replaced by production data products. Do not use."
    $entity.entity.attributes.name = "[DEPRECATED] test PBIX"
    $payload = @{
        entity = @{
            typeName = $entity.entity.typeName
            guid = $testProductGuid
            attributes = $entity.entity.attributes
        }
    } | ConvertTo-Json -Depth 10
    $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Update TDF MVP RTPCA similarly
$tdfProductGuid = "62e575bc-21db-4fbe-987a-910ca2888972"
Write-Host "Marking 'TDF MVP RTPCA' as deprecated..." -NoNewline
try {
    $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/${tdfProductGuid}?api-version=2022-03-01-preview" -Headers $headers
    $entity.entity.attributes.description = "[DEPRECATED] TDF MVP test product — replaced by production data products. Do not use."
    $entity.entity.attributes.name = "[DEPRECATED] TDF MVP RTPCA"
    $payload = @{
        entity = @{
            typeName = $entity.entity.typeName
            guid = $tdfProductGuid
            attributes = $entity.entity.attributes
        }
    } | ConvertTo-Json -Depth 10
    $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Sprint 4 Complete ===" -ForegroundColor Cyan
Write-Host "  Products created: $($productGuids.Count)"
Write-Host "  Test products deprecated: 2"
Write-Host ""
Write-Host "=== ALL SPRINTS 1-4 SUMMARY ===" -ForegroundColor Yellow
Write-Host "  Sprint 1: 12 Application Services updated with real descriptions"
Write-Host "  Sprint 2: 5 Domains + 3 Orgs + 5 LoBs created, 12 services linked"
Write-Host "  Sprint 3: 1 new glossary + 80 terms (total: 113)"
Write-Host "  Sprint 4: 6 production Data Products + 2 test products deprecated"
