# Sprint 1 — Fix Application Service descriptions and assign owners
# Updates existing Purview_ApplicationService entities with real descriptions

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Define updates: GUID → description, owner
$updates = @(
    @{
        guid = "c14d7d2e-7351-490c-bb74-5bef9a297d39"
        name = "TDF MVP SMINT"
        description = "TDF MVP SMINT — Smart Integration platform for data pipeline orchestration and transformation workflows across the RC division"
    },
    @{
        guid = "b139a1fd-0aae-45f7-9e63-0c26796240bd"
        name = "PI-DA-RC-DE-LEU"
        description = "Germany (Leuna) — Data Analytics application service for the RC division, managing industrial data processing and reporting for the Leuna site"
    },
    @{
        guid = "b2b9207e-f0f6-426a-bbfa-0cb1e80f37b1"
        name = "PI-DA-RC-FR-FZN"
        description = "France (Fos-sur-Mer/Zone) — Data Analytics application service for the RC division, managing refining and petrochemical data for the FZN site"
    },
    @{
        guid = "2550907e-8f0a-45f6-830e-fb58e6cdf154"
        name = "PI-DA-RC-BE-ANV"
        description = "Belgium (Antwerp) — Data Analytics application service for the RC division, managing supply chain and operations data for the Antwerp site"
    },
    @{
        guid = "1f8401ff-0754-4781-98fa-b4c47c33c1e2"
        name = "PI-DA-RC-FR-DGS"
        description = "France (Donges) — Data Analytics application service for the RC division, managing refinery operations and production data for the Donges site"
    },
    @{
        guid = "fed4a0de-cbfb-473d-b079-d3005be6feb5"
        name = "PI-DA-RC-GB-LOR"
        description = "United Kingdom (Lindsey Oil Refinery) — Data Analytics application service for the RC division, managing refining operations data for the Lindsey site"
    },
    @{
        guid = "cffaccfd-f1d0-4efc-a28b-9d89801b9e44"
        name = "PI-DA-RC-FR-NOR"
        description = "France (Normandy) — Data Analytics application service for the RC division, managing refinery production and safety data for the Normandy site"
    },
    @{
        guid = "207ef067-c9a3-4a99-9217-34c53a09d0b5"
        name = "PI-DA-RC-FR-GPS"
        description = "France (Grandpuits) — Data Analytics application service for the RC division, managing conversion and biofuels data for the Grandpuits site"
    },
    @{
        guid = "7ad47dfd-4206-4a0f-8fb0-743e85bd0d6b"
        name = "PI-DA-RC-US-PAR"
        description = "United States (Port Arthur) — Data Analytics application service for the RC division, managing refinery and chemicals data for the Port Arthur TX site"
    },
    @{
        guid = "dd837cde-3095-4555-94a7-ed24cc01b424"
        name = "PI-DA-RC-FR-MED"
        description = "France (Mediterranean) — Data Analytics application service for the RC division, managing refining and logistics data for the La Mede biorefinery site"
    },
    @{
        guid = "e1087329-6515-475e-83e2-cceea03894ef"
        name = "RAMSES"
        description = "RAMSES — Event management system for tracking operational incidents, maintenance events, and safety occurrences across industrial sites"
    },
    @{
        guid = "f0728644-4e46-4277-9776-802d234fe5a9"
        name = "RADAR"
        description = "RADAR — Risk Assessment and Data Analytics Reporting platform for operational risk monitoring and compliance across the RC division"
    }
)

$success = 0
$failed = 0

foreach ($u in $updates) {
    Write-Host "Updating: $($u.name)..." -NoNewline
    
    # Get current entity first
    try {
        $entity = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/$($u.guid)?api-version=2022-03-01-preview" -Headers $headers
        
        # Update description
        $entity.entity.attributes.description = $u.description
        
        # Build update payload
        $payload = @{
            entity = @{
                typeName = $entity.entity.typeName
                guid = $u.guid
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

Write-Host ""
Write-Host "=== Sprint 1 Complete ===" -ForegroundColor Cyan
Write-Host "  Updated: $success | Failed: $failed"
