# Add 3 umbrella terms directly to each of the 5 LoB root governance domains
# So that the LoB tile in the portal shows first-class glossary entries.

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api    = "?api-version=2026-03-20-preview"

# Owner contact GUIDs (Sprint 5d roster)
$owners = @{
    Finance    = "e8c4054b-55fd-4783-bc2f-a1ef32f8ea7b"
    Customer   = "c51caf82-91a2-4ad1-a12e-86970c20f1f8"
    HR         = "e38ff89a-e9e3-4cd9-bf6c-5f3b86e1c95e"
    Operations = "51ad0829-7e2e-4a0d-9a6c-6b1ef41edcdf"
    Technology = "77a408f9-1a36-49b5-bb43-ad4dabb05df4"
}

$LoBs = @(
    @{ id="da176475-282f-4f22-9a06-7661d0e25916"; name="Finance and ESG"; owner=$owners.Finance;
       terms=@(
         @{ name="Enterprise Financial KPI"; description="Cross-cutting financial indicator consolidated at LoB level (Revenue, EBITDA, Net Income, Cash Flow)."; acronyms=@("EFK") },
         @{ name="ESG Disclosure Metric";    description="Cross-cutting sustainability indicator reported under CSRD (Scope 1/2/3 emissions, Water Intensity, Diversity Index)."; acronyms=@("ESG", "CSRD") },
         @{ name="Financial Reporting Period"; description="Standard fiscal calendar boundary used across all Finance and ESG products (Month, Quarter, Year)."; acronyms=@("FRP") }
       )
    },
    @{ id="f1b1d5fe-3617-4786-9894-ffd8662bead7"; name="Customer and Sales"; owner=$owners.Customer;
       terms=@(
         @{ name="Customer Master Record"; description="Authoritative customer identity record consolidated across CRM, Salesforce, and Dataverse. Foundation of the Customer 360 product."; acronyms=@("CMR", "MDM-C") },
         @{ name="Customer Engagement Event"; description="Any tracked interaction between a customer and the company across web, mobile, branch, partner, or call-center channels."; acronyms=@("CEE") },
         @{ name="Sales Performance Indicator"; description="Cross-LoB sales metric (Pipeline, Win Rate, ARPU, Lead Conversion, Lifetime Value)."; acronyms=@("SPI") }
       )
    },
    @{ id="f64840cf-bac7-4d21-b43f-b02b3e9f5ba6"; name="HR and People"; owner=$owners.HR;
       terms=@(
         @{ name="Employee Master Record"; description="Authoritative employee identity and demographic record across all HR systems."; acronyms=@("EMR") },
         @{ name="Workforce Performance Indicator"; description="Cross-LoB people metric (Headcount, Attrition, Engagement, Time-to-Hire, Pay Gap)."; acronyms=@("WPI") },
         @{ name="People Lifecycle Event"; description="Standardised HR transaction (Hire, Promotion, Transfer, Compensation Change, Termination)."; acronyms=@("PLE") }
       )
    },
    @{ id="84f0ee4c-375b-4714-bd0d-a2d9dade9f36"; name="Operations and Industrial"; owner=$owners.Operations;
       terms=@(
         @{ name="Industrial Asset Identifier"; description="Cross-site identifier for any tracked physical asset (Equipment ID, Tag Number, Loop Number)."; acronyms=@("IAI") },
         @{ name="Operational Performance Indicator"; description="Cross-LoB operations metric (OEE, MTBF, MTTR, Production Yield, Lead Time)."; acronyms=@("OPI") },
         @{ name="Safety and Reliability Event"; description="Standardised operational event (Incident, Near Miss, Inspection, Maintenance, Downtime)."; acronyms=@("SRE") }
       )
    },
    @{ id="7f5695d1-8e2e-44f1-9c08-5c1e2455cee7"; name="Technology and Data Platform"; owner=$owners.Technology;
       terms=@(
         @{ name="Data Platform Health Indicator"; description="Cross-platform telemetry metric (Pipeline Freshness, Refresh Failure Rate, Query Latency, Schema Drift)."; acronyms=@("DPHI") },
         @{ name="Data Product Certification"; description="Endorsement level applied to a data product (Bronze, Silver, Gold, Platinum) reflecting governance maturity."; acronyms=@("DPC") },
         @{ name="Data Lineage Anchor"; description="Reference point in the lineage graph used for impact analysis and traceability across pipelines."; acronyms=@("DLA") }
       )
    }
)

$created = 0
$failed  = 0
foreach ($lob in $LoBs) {
    Write-Host "`n=== $($lob.name) ===" -ForegroundColor Cyan
    foreach ($t in $lob.terms) {
        $body = @{
            name        = $t.name
            description = $t.description
            domain      = $lob.id
            status      = "Published"
            acronyms    = $t.acronyms
            contacts    = @{
                owner   = @( @{ id = $lob.owner; description = "LoB Owner" } )
                steward = @( @{ id = $lob.owner; description = "LoB Steward" } )
            }
        } | ConvertTo-Json -Depth 6
        try {
            $r = Invoke-RestMethod -Uri "$dgBase/terms$api" -Headers $headers -Method Post -Body $body
            Write-Host "  ok $($t.name) [$($t.acronyms -join ', ')] :: $($r.id)"
            $created++
        } catch {
            $msg = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { $_.Exception.Message }
            Write-Host "  FAIL $($t.name) :: $msg" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host "`n========== Created: $created  Failed: $failed ==========" -ForegroundColor Green
