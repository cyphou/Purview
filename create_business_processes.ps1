# Sprint 6 — Create 5 cross-domain Purview_BusinessProcess entities
# Linked to their owning DataDomain (represents) and implementing ApplicationServices.

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com/catalog/api/atlas/v2"

# DataDomain GUIDs (Atlas Purview_DataDomain — Sprint 2)
$DD = @{
    Finance     = "befb3d6a-34cc-4464-ad8c-da0583257f21"
    Customer    = "604c1ab0-47cb-4a4a-89cf-a737021e1592"
    HR          = "e2b53231-ca20-4e97-b7fe-dd995e7c6d5f"
    Operations  = "32272856-a0cc-4633-9354-ba300c1515f1"
    Technology  = "d0366806-b679-45a9-84e3-b147e4a9b16d"
}

# ApplicationService GUIDs (Atlas — Sprint 1)
$AS = @{
    SAP_O02       = "e24430e0-74f8-4a51-b727-62ae59d489dd"
    SAP_O02_PSC   = "69cd42de-9399-4956-8d21-ca402847ac5d"
    SAP_P3A       = "018f9b55-323a-4dc1-a343-515f26c7c4ac"
    SAP_P8B       = "23127e44-f979-41fd-8c35-352c5642e62d"
    SAP_UNISOL    = "02d88cbb-ca57-477e-bfda-29fe381c7852"
    SAP_RC        = "7e487f2e-d4ea-4667-9f3d-f4b539ae86d3"
    RAMSES        = "e1087329-6515-475e-83e2-cceea03894ef"
    RADAR         = "f0728644-4e46-4277-9776-802d234fe5a9"
    TDF_SMINT     = "c14d7d2e-7351-490c-bb74-5bef9a297d39"
    PI_DE_LEU     = "b139a1fd-0aae-45f7-9e63-0c26796240bd"
    PI_FR_FZN     = "b2b9207e-f0f6-426a-bbfa-0cb1e80f37b1"
    PI_BE_ANV     = "2550907e-8f0a-45f6-830e-fb58e6cdf154"
    PI_FR_DGS     = "1f8401ff-0754-4781-98fa-b4c47c33c1e2"
    PI_GB_LOR     = "fed4a0de-cbfb-473d-b079-d3005be6feb5"
    PI_FR_NOR     = "cffaccfd-f1d0-4efc-a28b-9d89801b9e44"
    PI_FR_GPS     = "207ef067-c9a3-4a99-9217-34c53a09d0b5"
    PI_US_PAR     = "7ad47dfd-4206-4a0f-8fb0-743e85bd0d6b"
    PI_FR_MED     = "dd837cde-3095-4555-94a7-ed24cc01b424"
}

function New-AppRef([string]$guid) { @{ guid = $guid; typeName = "Purview_ApplicationService" } }
function New-SapRef([string]$guid) { @{ guid = $guid; typeName = "SAP application service" } }
function New-DDRef ([string]$guid) { @{ guid = $guid; typeName = "Purview_DataDomain" } }

$processes = @(
    @{
        name        = "Plan-to-Report"
        qn          = "process://plan-to-report"
        description = "End-to-end financial planning, budgeting, consolidation, and statutory + ESG reporting cycle. Covers FP&A through CSRD disclosure."
        domain      = $DD.Finance
        impl        = @( New-AppRef $AS.RADAR )
    },
    @{
        name        = "Order-to-Cash"
        qn          = "process://order-to-cash"
        description = "Customer order capture through invoicing, collection, and revenue recognition. Spans CRM, billing, AR, and customer master."
        domain      = $DD.Customer
        impl        = @( New-AppRef $AS.TDF_SMINT )
    },
    @{
        name        = "Hire-to-Retire"
        qn          = "process://hire-to-retire"
        description = "Full employee lifecycle: recruiting, onboarding, performance, compensation, learning, succession, and offboarding."
        domain      = $DD.HR
        impl        = @()
    },
    @{
        name        = "Equipment-to-Maintenance"
        qn          = "process://equipment-to-maintenance"
        description = "Industrial asset reliability lifecycle: equipment registration, inspection, preventive + corrective maintenance, work-order execution, safety incident handling."
        domain      = $DD.Operations
        impl        = @(
            (New-SapRef $AS.SAP_O02), (New-SapRef $AS.SAP_P3A), (New-SapRef $AS.SAP_P8B), (New-SapRef $AS.SAP_UNISOL),
            (New-AppRef $AS.RAMSES),
            (New-AppRef $AS.PI_DE_LEU), (New-AppRef $AS.PI_FR_FZN), (New-AppRef $AS.PI_BE_ANV),
            (New-AppRef $AS.PI_FR_DGS), (New-AppRef $AS.PI_GB_LOR), (New-AppRef $AS.PI_FR_NOR),
            (New-AppRef $AS.PI_FR_GPS), (New-AppRef $AS.PI_US_PAR), (New-AppRef $AS.PI_FR_MED)
        )
    },
    @{
        name        = "Data-Asset-to-Insight"
        qn          = "process://data-asset-to-insight"
        description = "Platform process from raw data ingestion through Lakehouse curation, semantic modeling, and consumption via Power BI / Fabric. Owns pipeline freshness and catalog completeness."
        domain      = $DD.Technology
        impl        = @( New-AppRef $AS.TDF_SMINT )
    }
)

$created = 0
foreach ($p in $processes) {
    $entity = @{
        entity = @{
            typeName   = "Purview_BusinessProcess"
            attributes = @{
                qualifiedName = $p.qn
                name          = $p.name
                description   = $p.description
            }
            relationshipAttributes = @{
                represents                  = (New-DDRef $p.domain)
                isImplementedBy_ApplicationService = $p.impl
            }
        }
    } | ConvertTo-Json -Depth 12

    try {
        $r = Invoke-RestMethod -Uri "$base/entity" -Headers $headers -Method Post -Body $entity
        $guid = ($r.guidAssignments.PSObject.Properties | Select-Object -First 1).Value
        Write-Host "  ✓ $($p.name) :: $guid"
        $created++
    } catch {
        $msg = $_.Exception.Message
        if ($_.ErrorDetails) { $msg = $_.ErrorDetails.Message }
        Write-Host "  ✗ $($p.name) :: $msg" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Created: $created / $($processes.Count) Business Processes"
