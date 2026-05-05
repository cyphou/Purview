# Sprint UC-G : Custom Metadata via the new /datagovernance/catalog/customMetadata endpoint
# Discovered 2026-05-05 — POST works with status="Published" and PRESERVES attribute names
# (unlike the old /attributes endpoint where name was overwritten with a GUID).
#
# Each "customMetadata" is a GROUP that contains typed attributes, scoped to:
#   - businessConcepts: ["DataProduct","Term","Asset",...]
#   - domains: list of domain GUIDs (or includesAll=true)
#   - dataProductTypes: ["Dataset","DashboardsOrReports","SemanticModel","AnalyticsModel",...]
#
# Verb cheat sheet:
#   POST /customMetadata                -> create group (status=Published required)
#   GET  /customMetadata                -> list all
#   GET  /customMetadata/{id}           -> single group
#   PUT  /customMetadata/{id}           -> update (must send FULL body)
#   DELETE                               -> 405 Not Allowed (use rename + portal hide)

$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

# ---- Helpers ------------------------------------------------------------
function New-Attr([string]$name, [string]$type = "string") {
    @{
        type     = $type
        status   = "Published"
        name     = $name
        isOptional = $true
        scope    = @{ inheritApplicableConstructsFromGroup = $true }
        options  = @{}
    }
}

function Invoke-MetaPost($body) {
    $json = $body | ConvertTo-Json -Depth 10
    $r = Invoke-WebRequest -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Post -Body $json -SkipHttpErrorCheck
    $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    if ($r.StatusCode -in 200,201) {
        $obj = $c | ConvertFrom-Json
        Write-Host "  ok  $($body.name)  id=$($obj.id)" -ForegroundColor Green
        return $obj
    } else {
        Write-Host "  FAIL $($body.name) :: HTTP $($r.StatusCode) $c" -ForegroundColor Red
        return $null
    }
}

# ---- Production groups --------------------------------------------------
$groups = @(
    @{
        name        = "Data Product Operations"
        type        = "BusinessConcept"
        status      = "Published"
        description = "Operational characteristics of a data product: refresh, classification, criticality, SLA, retention, PII flag."
        scope = @{
            applicableConstructs = @{
                businessConcepts   = @{ includesAll = $false; includes = @("DataProduct") }
                domains            = @{ includesAll = $true;  includes = @() }
                dataProductTypes   = @{ includesAll = $true;  includes = @() }
            }
        }
        attributes = @(
            (New-Attr "Refresh Frequency"),
            (New-Attr "Data Classification"),
            (New-Attr "Business Criticality"),
            (New-Attr "SLA Target"),
            (New-Attr "Personal Data"),
            (New-Attr "Retention Period")
        )
    },
    @{
        name        = "Data Product Compliance"
        type        = "BusinessConcept"
        status      = "Published"
        description = "Compliance and sourcing context for a data product: regulatory frameworks, source systems, cost center."
        scope = @{
            applicableConstructs = @{
                businessConcepts   = @{ includesAll = $false; includes = @("DataProduct") }
                domains            = @{ includesAll = $true;  includes = @() }
                dataProductTypes   = @{ includesAll = $true;  includes = @() }
            }
        }
        attributes = @(
            (New-Attr "Regulatory Framework"),
            (New-Attr "Source System"),
            (New-Attr "Cost Center")
        )
    },
    @{
        name        = "Glossary Term Governance"
        type        = "BusinessConcept"
        status      = "Published"
        description = "Governance metadata for glossary terms: calculation rule and regulatory reference."
        scope = @{
            applicableConstructs = @{
                businessConcepts   = @{ includesAll = $false; includes = @("Term") }
                domains            = @{ includesAll = $true;  includes = @() }
                dataProductTypes   = @{ includesAll = $true;  includes = @() }
            }
        }
        attributes = @(
            (New-Attr "Calculation Rule"),
            (New-Attr "Regulatory Reference")
        )
    }
)

Write-Host "=== Creating $($groups.Count) custom metadata groups ===" -ForegroundColor Cyan
$created = @()
foreach ($g in $groups) { $r = Invoke-MetaPost $g; if ($r) { $created += $r } }

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
$all = Invoke-RestMethod -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Get
foreach ($g in $all.value) {
    $attrs = ($g.attributes | ForEach-Object { $_.name }) -join ", "
    Write-Host ("  [{0,-30}] {1}  ({2} attrs: {3})" -f $g.name, $g.id, $g.attributes.Count, $attrs)
}
Write-Host "`nTotal groups: $($all.value.Count)" -ForegroundColor Green
