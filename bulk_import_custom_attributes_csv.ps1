# Sprint July-2026-C: Custom Attribute Values via CSV Bulk Import
#
# NEW DISCOVERY (April 2026): The bulk import CSV for data products and glossary terms
# includes "Column H and onward" for custom attribute values. This is potentially the
# ONLY programmatic path to set custom attribute values (REST PUT silently drops them).
#
# This script:
#   1) Queries the existing custom metadata groups + attributes from Purview
#   2) Generates valid CSV files for each DP and term (including custom attribute columns)
#   3) Uploads the CSVs via the bulk import REST endpoint (if available)
#   4) Falls back to generating ready-to-upload files if upload endpoint is portal-only
#   5) Reports: which attribute values were set vs still need portal entry
#
# Sources:
#   https://learn.microsoft.com/en-us/purview/unified-catalog-data-products-create-manage#bulk-import-data-products-preview
#   https://learn.microsoft.com/en-us/purview/unified-catalog-glossary-terms-create-manage#bulk-import-glossary-terms-preview

param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$OutputDir      = "docs",
    [switch]$UploadOnly,     # Skip CSV generation, try upload directly
    [switch]$GenerateOnly    # Generate CSVs but don't attempt upload
)

$ErrorActionPreference = "Stop"
$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://$PurviewAccount.purview.azure.com/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

function Invoke-Api($method, $uri, $body = $null, $contentType = "application/json") {
    $params = @{ Uri=$uri; Headers=$headers; Method=$method; SkipHttpErrorCheck=$true; ContentType=$contentType }
    if ($body) { $params.Body = $body }
    $r = Invoke-WebRequest @params
    $c = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
    [PSCustomObject]@{ Status=$r.StatusCode; Body=$c }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "=== Step 1: Load Custom Metadata Groups & Attributes ===" -ForegroundColor Cyan

$groups = (Invoke-RestMethod -Uri "$dgBase/customMetadata$api" -Headers $headers).value
Write-Host "  Found $($groups.Count) custom metadata group(s):" -ForegroundColor DarkGray
$attrMap = @{}   # flat: "Group::Attribute" -> attribute definition
foreach ($g in $groups) {
    Write-Host ("    [{0}] {1} — {2} attribute(s)" -f $g.id.Substring(0,8), $g.name, $g.attributes.Count) -ForegroundColor DarkGray
    foreach ($a in $g.attributes) {
        $key = "$($g.name)::$($a.name)"
        $attrMap[$key] = @{ groupId=$g.id; groupName=$g.name; attrId=$a.id; attrName=$a.name; type=$a.type }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 2: Probe Bulk Import Endpoints ===" -ForegroundColor Cyan

# The portal uses a CSV upload flow — try to find the REST counterpart
$importPaths = @(
    "POST $dgBase/dataproducts/import$api"
    "POST $dgBase/dataproducts/bulkImport$api"
    "POST $dgBase/dataproducts/batch$api"
    "GET  $dgBase/dataproducts/import/template$api"
    "POST $dgBase/terms/import$api"
    "POST $dgBase/terms/bulkImport$api"
    "GET  $dgBase/terms/import/template$api"
)

$importEndpoint_DP   = $null
$importEndpoint_Term = $null
foreach ($p in $importPaths) {
    $verb, $url = $p -split " ", 2
    $r = Invoke-Api $verb $url "{}"
    $icon = if ($r.Status -notin 404,405) { "✅" } else { "  " }
    Write-Host ("  {0} [{1}] {2}" -f $icon, $r.Status, $p) -ForegroundColor $(if ($r.Status -notin 404,405) { "Green" } else { "DarkGray" })
    if ($r.Status -notin 404,405) {
        if ($p -like "*dataproducts*" -and -not $importEndpoint_DP) { $importEndpoint_DP = @{ verb=$verb; url=$url } }
        if ($p -like "*terms*" -and -not $importEndpoint_Term)      { $importEndpoint_Term = @{ verb=$verb; url=$url } }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 3: Generate CSV Files with Custom Attribute Columns ===" -ForegroundColor Cyan

# Custom attribute values to set per data product
# Schema from Microsoft docs (Column H+): attribute column names match the attribute NAME
$dpAttributeValues = @(
    @{
        name         = "Executive Financial Dashboards"
        owners       = "financeowner@pdedemopurv.onmicrosoft.com"
        type         = "DashboardsOrReports"
        audience     = "Executive"
        endorsed     = "True"
        description  = "Executive-level financial dashboards providing consolidated P&L, cash flow, and ESG KPIs for board reporting."
        businessUse  = "Used by CFO and Finance Business Partners for weekly executive briefings, month-end close, and board pack preparation."
        attrs        = @{
            "Refresh Frequency"    = "Daily"
            "Data Classification"  = "Confidential"
            "Business Criticality" = "High"
            "SLA Target"           = "99.9%"
            "Personal Data"        = "False"
            "Retention Period"     = "7 years"
            "Regulatory Framework" = "IFRS, CSRD"
            "Source System"        = "Finance Report (Power BI)"
            "Cost Center"          = "CC-FIN-001"
        }
    },
    @{
        name         = "ESG and CSRD Reporting Pack"
        owners       = "financeowner@pdedemopurv.onmicrosoft.com"
        type         = "DashboardsOrReports"
        audience     = "Executive"
        endorsed     = "True"
        description  = "Consolidated ESG and CSRD disclosure metrics for regulatory reporting under EU taxonomy and ESRS standards."
        businessUse  = "Used by the Sustainability team and Chief Risk Officer for CSRD annual report, board ESG committee, and regulatory submissions."
        attrs        = @{
            "Refresh Frequency"    = "Monthly"
            "Data Classification"  = "Restricted"
            "Business Criticality" = "Critical"
            "SLA Target"           = "99.5%"
            "Personal Data"        = "False"
            "Retention Period"     = "10 years"
            "Regulatory Framework" = "CSRD, EU Taxonomy, ESRS"
            "Source System"        = "Finance Report, ESG Data Lake"
            "Cost Center"          = "CC-ESG-002"
        }
    },
    @{
        name         = "Customer 360"
        owners       = "customer.owner@pdedemopurv.onmicrosoft.com"
        type         = "Dataset"
        audience     = "BusinessAnalyst"
        endorsed     = "True"
        description  = "Unified customer master record spanning CRM, ERP, and digital touchpoints. Single source of truth for all customer-facing analytics."
        businessUse  = "Used by sales, marketing, and customer success teams for segmentation, churn prediction, NPS tracking, and campaign targeting."
        attrs        = @{
            "Refresh Frequency"    = "Near Real-Time (15 min)"
            "Data Classification"  = "Confidential"
            "Business Criticality" = "Critical"
            "SLA Target"           = "99.9%"
            "Personal Data"        = "True"
            "Retention Period"     = "5 years"
            "Regulatory Framework" = "GDPR, CCPA"
            "Source System"        = "Salesforce, Dynamics 365"
            "Cost Center"          = "CC-CRM-010"
        }
    },
    @{
        name         = "Workforce Analytics Dashboard"
        owners       = "hr.owner@pdedemopurv.onmicrosoft.com"
        type         = "DashboardsOrReports"
        audience     = "BusinessUser"
        endorsed     = "True"
        description  = "Comprehensive workforce analytics covering headcount, attrition, compensation equity, and talent development metrics."
        businessUse  = "Used by CHRO and HR Business Partners for monthly people reviews, compensation cycle planning, and DEI reporting."
        attrs        = @{
            "Refresh Frequency"    = "Weekly"
            "Data Classification"  = "Restricted"
            "Business Criticality" = "High"
            "SLA Target"           = "99.0%"
            "Personal Data"        = "True"
            "Retention Period"     = "7 years"
            "Regulatory Framework" = "GDPR, Labor Law"
            "Source System"        = "SAP HCM, Workday"
            "Cost Center"          = "CC-HR-005"
        }
    },
    @{
        name         = "Operational Performance Hub"
        owners       = "ops.owner@pdedemopurv.onmicrosoft.com"
        type         = "Dataset"
        audience     = "DataEngineer"
        endorsed     = "True"
        description  = "Industrial asset performance, maintenance work orders, and supply chain KPIs aggregated from SAP PM, PI historian, and IoT sensors."
        businessUse  = "Used by Plant Managers and Reliability Engineers for OEE monitoring, predictive maintenance scheduling, and TRIR safety reporting."
        attrs        = @{
            "Refresh Frequency"    = "Hourly"
            "Data Classification"  = "Internal"
            "Business Criticality" = "High"
            "SLA Target"           = "99.5%"
            "Personal Data"        = "False"
            "Retention Period"     = "5 years"
            "Regulatory Framework" = "ISO 55001, IEC 61511"
            "Source System"        = "SAP PM, PI Historian, IoT Hub"
            "Cost Center"          = "CC-OPS-020"
        }
    },
    @{
        name         = "Data Platform Health Monitor"
        owners       = "tech.owner@pdedemopurv.onmicrosoft.com"
        type         = "DashboardsOrReports"
        audience     = "DataEngineer"
        endorsed     = "True"
        description  = "Platform observability dashboard tracking pipeline SLAs, data quality scores, lineage coverage, and governance adoption metrics."
        businessUse  = "Used by the Data Platform team for daily ops review, SLA breach alerting, and quarterly governance maturity reporting."
        attrs        = @{
            "Refresh Frequency"    = "Real-Time"
            "Data Classification"  = "Internal"
            "Business Criticality" = "High"
            "SLA Target"           = "99.9%"
            "Personal Data"        = "False"
            "Retention Period"     = "3 years"
            "Regulatory Framework" = "SOX (IT Controls)"
            "Source System"        = "Azure Monitor, Purview, Fabric"
            "Cost Center"          = "CC-DPT-030"
        }
    }
)

# Build CSV — get distinct attribute names from all rows
$allAttrNames = @()
foreach ($dp in $dpAttributeValues) { $allAttrNames += $dp.attrs.Keys }
$allAttrNames = $allAttrNames | Select-Object -Unique | Sort-Object

# Standard columns (A-G) match the bulk import schema from docs
$headers_csv = @("name", "owners", "type", "audience", "endorsed", "description", "business use") + $allAttrNames

$csvRows = @()
foreach ($dp in $dpAttributeValues) {
    $row = [ordered]@{
        name           = $dp.name
        owners         = $dp.owners
        type           = $dp.type
        audience       = $dp.audience
        endorsed       = $dp.endorsed
        description    = $dp.description
        "business use" = $dp.businessUse
    }
    foreach ($attr in $allAttrNames) {
        $row[$attr] = if ($dp.attrs[$attr]) { $dp.attrs[$attr] } else { "" }
    }
    $csvRows += [PSCustomObject]$row
}

$dpCsvPath = "$OutputDir/bulk_import_dataproducts_with_attributes.csv"
$csvRows | Export-Csv -Path $dpCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "  ✅ DP CSV written: $dpCsvPath ($($csvRows.Count) rows, $($allAttrNames.Count) attribute columns)" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 4: Try REST Upload of CSV ===" -ForegroundColor Cyan

if ($GenerateOnly) {
    Write-Host "  [GenerateOnly] CSV files ready — upload via portal:" -ForegroundColor Yellow
    Write-Host "    Portal → Unified Catalog → Data products → Import → upload $dpCsvPath" -ForegroundColor DarkGray
} elseif ($importEndpoint_DP) {
    Write-Host "  Uploading to: $($importEndpoint_DP.url)" -ForegroundColor DarkGray
    $csvContent = Get-Content $dpCsvPath -Raw
    $boundary   = "----WebKitFormBoundary$(Get-Random)"
    $multipart  = "--$boundary`r`nContent-Disposition: form-data; name=`"file`"; filename=`"import.csv`"`r`nContent-Type: text/csv`r`n`r`n$csvContent`r`n--$boundary--"
    $r = Invoke-Api $importEndpoint_DP.verb $importEndpoint_DP.url $multipart "multipart/form-data; boundary=$boundary"
    if ($r.Status -in 200,201,202) {
        Write-Host "  ✅ Upload accepted: HTTP $($r.Status)" -ForegroundColor Green
        $obj = $r.Body | ConvertFrom-Json
        Write-Host ("  Job ID: {0}" -f $(if ($obj.id) { $obj.id } else { $obj.jobId })) -ForegroundColor DarkGray
    } else {
        Write-Host ("  [{0}] {1}" -f $r.Status, $r.Body.Substring(0,[Math]::Min(300,$r.Body.Length))) -ForegroundColor Yellow
        Write-Host "  → Portal upload path: Unified Catalog → Data products → Import" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  ⚠️  No REST import endpoint found — use portal upload:" -ForegroundColor Yellow
    Write-Host "    1. Open: https://purview.microsoft.com/ → Unified Catalog → Catalog management → Governance domains" -ForegroundColor DarkGray
    Write-Host "    2. Select a governance domain → Data products → View all → Import" -ForegroundColor DarkGray
    Write-Host "    3. Upload: $dpCsvPath" -ForegroundColor DarkGray
    Write-Host "    (Column H+ in the CSV contains your custom attribute values)" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 5: Verify REST PUT Still Drops Values (known limitation check) ===" -ForegroundColor Cyan

# Probe: try to set a custom attribute value via REST PUT on a data product
# If this now works (July 2026), we can retire the CSV workaround
$dpId   = "4baeadc4-224c-43be-93a5-819ed2fb9e97"  # Executive Financial Dashboards
$dpFull = Invoke-RestMethod -Uri "$dgBase/dataproducts/$dpId$api" -Headers $headers

# Add a test custom attribute in every known body field shape
$testShapes = @("customMetadata", "customAttributes", "attributes", "businessConceptAttributes", "metadata")
$anyWorked  = $false
foreach ($field in $testShapes) {
    $testBody = $dpFull | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $testBody | Add-Member -NotePropertyName $field -NotePropertyValue @(@{name="Refresh Frequency"; value="TEST_$(Get-Date -Format 'HHmmss')"}) -Force
    $r = Invoke-Api "PUT" "$dgBase/dataproducts/$dpId$api" ($testBody | ConvertTo-Json -Depth 10)
    if ($r.Status -eq 200) {
        $readBack = Invoke-RestMethod -Uri "$dgBase/dataproducts/$dpId$api" -Headers $headers
        if ($readBack.$field -and ($readBack.$field | Where-Object name -EQ "Refresh Frequency")) {
            Write-Host ("  ✅ BREAKTHROUGH: field '{0}' now persists via REST PUT!" -f $field) -ForegroundColor Green
            $anyWorked = $true
        } else {
            Write-Host ("  [{0}] field '{1}': HTTP 200 but value silently dropped (still broken)" -f $r.Status, $field) -ForegroundColor DarkGray
        }
    }
}
if (-not $anyWorked) {
    Write-Host "  ❌ Custom attribute REST PUT still silently drops values — CSV/portal required." -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  CSV generated: $dpCsvPath"
Write-Host "  Attribute columns included: $($allAttrNames -join ', ')"
Write-Host "  Upload endpoint found: $(if ($importEndpoint_DP) { '✅ ' + $importEndpoint_DP.url } else { '❌ portal-only' })"
Write-Host "  REST PUT values: $(if ($anyWorked) { '✅ NOW WORKS' } else { '❌ still silently dropped' })"
