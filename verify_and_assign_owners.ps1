# Verify all governance objects created in Sprints 1-4
# Then assign unique owners to every entity

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  VERIFICATION: All Governance Objects" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# 1. Check Governance Domains
Write-Host "`n=== GOVERNANCE DOMAINS ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"entityType":"Purview_DataDomain"},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
Write-Host "Found: $($r.'@search.count') domains"
$r.value | ForEach-Object { Write-Host "  OK  $($_.id) | $($_.name)" -ForegroundColor Green }

# 2. Check Organizations
Write-Host "`n=== ORGANIZATIONS ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"entityType":"Purview_Organization"},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
Write-Host "Found: $($r.'@search.count') organizations"
$r.value | ForEach-Object { Write-Host "  OK  $($_.id) | $($_.name)" -ForegroundColor Green }

# 3. Check Lines of Business
Write-Host "`n=== LINES OF BUSINESS ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"entityType":"Purview_LineOfBusiness"},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
Write-Host "Found: $($r.'@search.count') lines of business"
$r.value | ForEach-Object { Write-Host "  OK  $($_.id) | $($_.name)" -ForegroundColor Green }

# 4. Check Application Services
Write-Host "`n=== APPLICATION SERVICES ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"or":[{"entityType":"Purview_ApplicationService"},{"entityType":"SAP application service"}]},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
Write-Host "Found: $($r.'@search.count') application services"
$r.value | ForEach-Object { Write-Host "  OK  $($_.id) | $($_.entityType) | $($_.name)" -ForegroundColor Green }

# 5. Check Data Products
Write-Host "`n=== DATA PRODUCTS ===" -ForegroundColor Cyan
$body = '{"keywords":"*","filter":{"or":[{"entityType":"Purview_Product"},{"entityType":"Digital Product TDF"}]},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
Write-Host "Found: $($r.'@search.count') data products"
$r.value | ForEach-Object { Write-Host "  OK  $($_.id) | $($_.entityType) | $($_.name)" -ForegroundColor Green }

# 6. Check Glossaries & Term counts
Write-Host "`n=== GLOSSARIES ===" -ForegroundColor Cyan
$glossaries = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary?api-version=2022-03-01-preview" -Headers $headers
$totalTerms = 0
$glossaries | ForEach-Object {
    $tc = if ($_.terms) { $_.terms.Count } else { 0 }
    $totalTerms += $tc
    Write-Host "  OK  $($_.guid) | $($_.name) | $tc terms" -ForegroundColor Green
}
Write-Host "  Total terms: $totalTerms" -ForegroundColor Yellow

Write-Host "`n==========================================" -ForegroundColor Yellow
Write-Host "  ASSIGNING OWNERS" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# Owner assignments — different owner per entity
$ownerMap = @(
    # Application Services (RC sites)
    @{ guid = "b139a1fd-0aae-45f7-9e63-0c26796240bd"; owner = "Hans Mueller"; expert = "hans.mueller@company.com" }          # PI-DA-RC-DE-LEU
    @{ guid = "b2b9207e-f0f6-426a-bbfa-0cb1e80f37b1"; owner = "Pierre Martin"; expert = "pierre.martin@company.com" }         # PI-DA-RC-FR-FZN
    @{ guid = "2550907e-8f0a-45f6-830e-fb58e6cdf154"; owner = "Jan Peeters"; expert = "jan.peeters@company.com" }              # PI-DA-RC-BE-ANV
    @{ guid = "1f8401ff-0754-4781-98fa-b4c47c33c1e2"; owner = "Claire Dubois"; expert = "claire.dubois@company.com" }          # PI-DA-RC-FR-DGS
    @{ guid = "fed4a0de-cbfb-473d-b079-d3005be6feb5"; owner = "James Wilson"; expert = "james.wilson@company.com" }            # PI-DA-RC-GB-LOR
    @{ guid = "cffaccfd-f1d0-4efc-a28b-9d89801b9e44"; owner = "Sophie Laurent"; expert = "sophie.laurent@company.com" }        # PI-DA-RC-FR-NOR
    @{ guid = "207ef067-c9a3-4a99-9217-34c53a09d0b5"; owner = "Marc Lefevre"; expert = "marc.lefevre@company.com" }            # PI-DA-RC-FR-GPS
    @{ guid = "7ad47dfd-4206-4a0f-8fb0-743e85bd0d6b"; owner = "Robert Johnson"; expert = "robert.johnson@company.com" }        # PI-DA-RC-US-PAR
    @{ guid = "dd837cde-3095-4555-94a7-ed24cc01b424"; owner = "Antoine Mercier"; expert = "antoine.mercier@company.com" }      # PI-DA-RC-FR-MED
    @{ guid = "e1087329-6515-475e-83e2-cceea03894ef"; owner = "Nathalie Bernard"; expert = "nathalie.bernard@company.com" }    # RAMSES
    @{ guid = "f0728644-4e46-4277-9776-802d234fe5a9"; owner = "Olivier Girard"; expert = "olivier.girard@company.com" }        # RADAR
    @{ guid = "c14d7d2e-7351-490c-bb74-5bef9a297d39"; owner = "Thomas Schneider"; expert = "thomas.schneider@company.com" }    # TDF MVP SMINT

    # Governance Domains
    @{ guid = "befb3d6a-34cc-4464-ad8c-da0583257f21"; owner = "Marie Fontaine"; expert = "marie.fontaine@company.com" }        # Finance and ESG
    @{ guid = "604c1ab0-47cb-4a4a-89cf-a737021e1592"; owner = "David Moreau"; expert = "david.moreau@company.com" }            # Customer and Sales
    @{ guid = "e2b53231-ca20-4e97-b7fe-dd995e7c6d5f"; owner = "Isabelle Petit"; expert = "isabelle.petit@company.com" }        # HR and People
    @{ guid = "32272856-a0cc-4633-9354-ba300c1515f1"; owner = "Philippe Rousseau"; expert = "philippe.rousseau@company.com" }  # Operations and Industrial
    @{ guid = "d0366806-b679-45a9-84e3-b147e4a9b16d"; owner = "Alexandre Dupont"; expert = "alexandre.dupont@company.com" }    # Technology and Data Platform

    # Organizations
    @{ guid = "efe8fb35-43af-454f-8af7-8ca66c6be5ca"; owner = "Catherine Blanc"; expert = "catherine.blanc@company.com" }      # Group
    @{ guid = "aa5af5df-5597-45ef-8a8c-9e736472441a"; owner = "Frederic Morel"; expert = "frederic.morel@company.com" }        # RC Division
    @{ guid = "882ee27a-6b38-498d-98f0-27cd7ee79057"; owner = "Laura Simon"; expert = "laura.simon@company.com" }              # Company B

    # Lines of Business
    @{ guid = "51537710-b9ec-4ce8-a72d-991da02d5887"; owner = "Vincent Roux"; expert = "vincent.roux@company.com" }            # Supply Chain and Logistics
    @{ guid = "c83d2bff-d8d2-4e89-b8e6-2a3d3175f38d"; owner = "Emilie Fournier"; expert = "emilie.fournier@company.com" }      # Digital Services
    @{ guid = "34999082-9edb-4a5f-ba05-2cbe032f4645"; owner = "Nicolas Lambert"; expert = "nicolas.lambert@company.com" }      # Analytics and BI
    @{ guid = "182e28fe-e3e0-4085-900d-24cdec281fae"; owner = "Christophe Bonnet"; expert = "christophe.bonnet@company.com" }  # Industrial Operations
    @{ guid = "225ecb41-153d-4366-9ce0-76b361cee3f9"; owner = "Valerie Leroy"; expert = "valerie.leroy@company.com" }          # Corporate Functions

    # Production Data Products
    @{ guid = "c30a209a-8764-4b03-a95b-69f62ea3a64c"; owner = "Marie Fontaine"; expert = "marie.fontaine@company.com" }        # Executive Financial Dashboards
    @{ guid = "495072be-66ff-4062-b122-1acd46efdd9d"; owner = "Sandrine Chevalier"; expert = "sandrine.chevalier@company.com" } # ESG and CSRD Reporting Pack
    @{ guid = "efb1058d-5a3f-4464-b39a-bf4f1096b6cd"; owner = "David Moreau"; expert = "david.moreau@company.com" }            # Customer 360
    @{ guid = "1ae39b7b-8a9a-4a13-9670-fa0a479bfc69"; owner = "Isabelle Petit"; expert = "isabelle.petit@company.com" }        # Workforce Analytics
    @{ guid = "0d633bc1-5014-41c6-ad50-b9f4249bc565"; owner = "Philippe Rousseau"; expert = "philippe.rousseau@company.com" }  # Operational Performance Hub
    @{ guid = "25db6129-20d4-4ab8-9fef-f2e4e356ced5"; owner = "Alexandre Dupont"; expert = "alexandre.dupont@company.com" }    # Data Platform Health
)

$success = 0
$failed = 0

foreach ($item in $ownerMap) {
    try {
        $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/$($item.guid)?api-version=2022-03-01-preview" -Headers $headers
        $name = $entity.entity.attributes.name
        Write-Host "  Setting owner on: $name -> $($item.owner)..." -NoNewline

        $entity.entity.attributes.owner = $item.owner

        $payload = @{
            entity = @{
                typeName = $entity.entity.typeName
                guid = $item.guid
                attributes = $entity.entity.attributes
            }
        } | ConvertTo-Json -Depth 10

        $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $payload
        Write-Host " OK" -ForegroundColor Green
        $success++
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n==========================================" -ForegroundColor Yellow
Write-Host "  SUMMARY" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Owners assigned: $success | Failed: $failed"
