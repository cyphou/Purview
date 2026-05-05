# Sprint 2 — Create Governance Domains, Organization, and LineOfBusiness entities
# Then link existing Application Services to their domains

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

$collectionId = "kxwjyq"  # Domain Global collection

Write-Host "=== STEP 1: Create Governance Domains ===" -ForegroundColor Cyan

$domains = @(
    @{ name = "Finance and ESG"; qn = "governance://domains/finance-esg"; desc = "Financial reporting, ESG/CSRD compliance, profitability metrics, audit and regulatory data" },
    @{ name = "Customer and Sales"; qn = "governance://domains/customer-sales"; desc = "CRM, customer lifecycle, sales analytics, Salesforce data, customer experience metrics" },
    @{ name = "HR and People"; qn = "governance://domains/hr-people"; desc = "Employee data, workforce analytics, compensation, benefits, talent management, diversity and inclusion" },
    @{ name = "Operations and Industrial"; qn = "governance://domains/operations-industrial"; desc = "Maintenance, equipment, supply chain, SAP processes, IoT, safety, refinery and plant operations" },
    @{ name = "Technology and Data Platform"; qn = "governance://domains/technology-platform"; desc = "Fabric artifacts, lakehouses, data pipelines, data engineering, platform health, catalog completeness" }
)

$domainGuids = @{}

foreach ($d in $domains) {
    Write-Host "Creating domain: $($d.name)..." -NoNewline
    $payload = @{
        entity = @{
            typeName = "Purview_DataDomain"
            attributes = @{
                name = $d.name
                qualifiedName = $d.qn
                description = $d.desc
            }
            collectionId = $collectionId
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        $guid = $result.guidAssignments.PSObject.Properties.Value
        if (-not $guid) { $guid = ($result.mutatedEntities.CREATE | Select-Object -First 1).guid }
        if (-not $guid) { $guid = ($result.mutatedEntities.UPDATE | Select-Object -First 1).guid }
        $domainGuids[$d.name] = $guid
        Write-Host " OK (GUID: $guid)" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== STEP 2: Create Organization Entities ===" -ForegroundColor Cyan

$orgs = @(
    @{ name = "Group"; qn = "governance://org/group"; desc = "Parent organization — group-level entity encompassing all divisions and business units" },
    @{ name = "RC Division"; qn = "governance://org/rc-division"; desc = "Refining and Chemicals division — manages refinery operations, petrochemicals, and biofuels across multiple sites" },
    @{ name = "Company B"; qn = "governance://org/company-b"; desc = "Company B business entity — dedicated data assets and analytics for Company B operations" }
)

$orgGuids = @{}

foreach ($o in $orgs) {
    Write-Host "Creating org: $($o.name)..." -NoNewline
    $payload = @{
        entity = @{
            typeName = "Purview_Organization"
            attributes = @{
                name = $o.name
                qualifiedName = $o.qn
                description = $o.desc
            }
            collectionId = $collectionId
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        $guid = $result.guidAssignments.PSObject.Properties.Value
        if (-not $guid) { $guid = ($result.mutatedEntities.CREATE | Select-Object -First 1).guid }
        if (-not $guid) { $guid = ($result.mutatedEntities.UPDATE | Select-Object -First 1).guid }
        $orgGuids[$o.name] = $guid
        Write-Host " OK (GUID: $guid)" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== STEP 3: Create LineOfBusiness Entities ===" -ForegroundColor Cyan

$lobs = @(
    @{ name = "Supply Chain and Logistics"; qn = "governance://lob/supply-chain"; desc = "Supply chain management, logistics, procurement, and inventory operations" },
    @{ name = "Digital Services"; qn = "governance://lob/digital-services"; desc = "Digital transformation, data analytics platforms, and IT-driven business services" },
    @{ name = "Analytics and BI"; qn = "governance://lob/analytics-bi"; desc = "Business intelligence, reporting, dashboards, and data-driven decision support" },
    @{ name = "Industrial Operations"; qn = "governance://lob/industrial-ops"; desc = "Plant operations, refining processes, maintenance, and operational technology" },
    @{ name = "Corporate Functions"; qn = "governance://lob/corporate-functions"; desc = "Finance, HR, legal, compliance, and corporate support functions" }
)

$lobGuids = @{}

foreach ($l in $lobs) {
    Write-Host "Creating LoB: $($l.name)..." -NoNewline
    $payload = @{
        entity = @{
            typeName = "Purview_LineOfBusiness"
            attributes = @{
                name = $l.name
                qualifiedName = $l.qn
                description = $l.desc
            }
            collectionId = $collectionId
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        $guid = $result.guidAssignments.PSObject.Properties.Value
        if (-not $guid) { $guid = ($result.mutatedEntities.CREATE | Select-Object -First 1).guid }
        if (-not $guid) { $guid = ($result.mutatedEntities.UPDATE | Select-Object -First 1).guid }
        $lobGuids[$l.name] = $guid
        Write-Host " OK (GUID: $guid)" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== STEP 4: Link Application Services to Domains ===" -ForegroundColor Cyan

# Map services to their domain
$serviceToDomain = @{
    "c14d7d2e-7351-490c-bb74-5bef9a297d39" = "Technology and Data Platform"   # TDF MVP SMINT
    "b139a1fd-0aae-45f7-9e63-0c26796240bd" = "Operations and Industrial"       # PI-DA-RC-DE-LEU
    "b2b9207e-f0f6-426a-bbfa-0cb1e80f37b1" = "Operations and Industrial"       # PI-DA-RC-FR-FZN
    "2550907e-8f0a-45f6-830e-fb58e6cdf154" = "Operations and Industrial"       # PI-DA-RC-BE-ANV
    "1f8401ff-0754-4781-98fa-b4c47c33c1e2" = "Operations and Industrial"       # PI-DA-RC-FR-DGS
    "fed4a0de-cbfb-473d-b079-d3005be6feb5" = "Operations and Industrial"       # PI-DA-RC-GB-LOR
    "cffaccfd-f1d0-4efc-a28b-9d89801b9e44" = "Operations and Industrial"       # PI-DA-RC-FR-NOR
    "207ef067-c9a3-4a99-9217-34c53a09d0b5" = "Operations and Industrial"       # PI-DA-RC-FR-GPS
    "7ad47dfd-4206-4a0f-8fb0-743e85bd0d6b" = "Operations and Industrial"       # PI-DA-RC-US-PAR
    "dd837cde-3095-4555-94a7-ed24cc01b424" = "Operations and Industrial"       # PI-DA-RC-FR-MED
    "e1087329-6515-475e-83e2-cceea03894ef" = "Operations and Industrial"       # RAMSES
    "f0728644-4e46-4277-9776-802d234fe5a9" = "Operations and Industrial"       # RADAR
}

$linked = 0
foreach ($svcGuid in $serviceToDomain.Keys) {
    $domainName = $serviceToDomain[$svcGuid]
    $domainGuid = $domainGuids[$domainName]
    
    if (-not $domainGuid) {
        Write-Host "  Skipping $svcGuid — no domain GUID for '$domainName'" -ForegroundColor Yellow
        continue
    }
    
    try {
        # Get current entity
        $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/${svcGuid}?api-version=2022-03-01-preview" -Headers $headers
        $svcName = $entity.entity.attributes.name
        Write-Host "Linking $svcName -> $domainName..." -NoNewline
        
        # Update with relationship
        $payload = @{
            entity = @{
                typeName = $entity.entity.typeName
                guid = $svcGuid
                attributes = $entity.entity.attributes
                relationshipAttributes = @{
                    represents = @{
                        typeName = "Purview_DataDomain"
                        guid = $domainGuid
                    }
                }
            }
        } | ConvertTo-Json -Depth 10
        
        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        Write-Host " OK" -ForegroundColor Green
        $linked++
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Sprint 2 Complete ===" -ForegroundColor Cyan
Write-Host "  Domains created: $($domainGuids.Count)"
Write-Host "  Organizations created: $($orgGuids.Count)"
Write-Host "  Lines of Business created: $($lobGuids.Count)"
Write-Host "  Services linked to domains: $linked"

# Export GUIDs for downstream sprints
$sprint2Results = @{
    domains = $domainGuids
    organizations = $orgGuids
    linesOfBusiness = $lobGuids
}
$sprint2Results | ConvertTo-Json -Depth 5 | Out-File "c:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview\sprint2_guids.json" -Encoding utf8
Write-Host "GUIDs exported to sprint2_guids.json"
