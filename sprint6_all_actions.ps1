########################################
# Sprint 6 — Comprehensive Governance Actions
# 1. Create 6 UC Data Products
# 2. Create 5 Business Process entities (Data Map / Atlas)
# 3. Rename cryptic collections
# 4. Try DQ rules API
# 5. Link sample terms to assets
# 6. Verify ghost cleanup
########################################

$ErrorActionPreference = "Continue"
$base = "https://pdedemopurv.purview.azure.com"
$ucApi = "2026-03-20-preview"
$atlasApi = "2022-08-01-preview"

# --- Auth ---
$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
Write-Host "`n========================================"
Write-Host " AUTH"
Write-Host "========================================`n"
Write-Host "Token acquired: $($token.Substring(0,20))..."

# --- Demo Users ---
$users = Get-Content "demo_users.json" | ConvertFrom-Json

# --- Domain IDs (from UC) ---
$doms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?api-version=$ucApi" -Headers $headers).value
$domMap = @{}
$doms | ForEach-Object { $domMap[$_.name] = $_.id }

Write-Host "`n========================================"
Write-Host " PHASE 1 — CREATE 6 UC DATA PRODUCTS"
Write-Host "========================================`n"

$dataProducts = @(
    @{
        name = "Executive Financial Dashboards"
        description = "C-suite financial KPIs — P&L, Cash Flow, profitability, working capital. Refreshed daily from SAP and Fabric lakehouse. Primary consumers: CEO, CFO, Board members."
        domainId = $domMap["Finance and ESG"]
        owners = @(
            @{ id = $users.financeowner; contactType = "Owner" }
            @{ id = $users.cfo; contactType = "Expert" }
        )
    },
    @{
        name = "ESG and CSRD Reporting Pack"
        description = "Sustainability metrics for regulatory compliance — Scope 1/2/3 emissions, carbon footprint, social and governance scores, CSRD-aligned indicators. Refreshed monthly."
        domainId = $domMap["Finance and ESG"]
        owners = @(
            @{ id = $users.financeowner; contactType = "Owner" }
            @{ id = $users.financesteward; contactType = "Expert" }
            @{ id = $users.dpo; contactType = "Expert" }
        )
    },
    @{
        name = "Customer 360"
        description = "Unified customer view combining CRM, Salesforce, and Dataverse transactional data. Includes demographics, purchase history, NPS, churn risk. Refreshed daily."
        domainId = $domMap["Customer and Sales"]
        owners = @(
            @{ id = $users.'customer.owner'; contactType = "Owner" }
            @{ id = $users.'customer.steward'; contactType = "Expert" }
        )
    },
    @{
        name = "Workforce Analytics"
        description = "Employee demographics, attrition trends, engagement scores, compensation analytics, diversity metrics. Sourced from HR systems. Refreshed weekly."
        domainId = $domMap["HR and People"]
        owners = @(
            @{ id = $users.'hr.owner'; contactType = "Owner" }
            @{ id = $users.'hr.steward'; contactType = "Expert" }
        )
    },
    @{
        name = "Operational Performance Hub"
        description = "Equipment OEE, maintenance KPIs (MTBF, MTTR), safety incident tracking, supply chain metrics. Sourced from SAP, RAMSES, and IoT sensors. Near real-time."
        domainId = $domMap["Operations and Industrial"]
        owners = @(
            @{ id = $users.'ops.owner'; contactType = "Owner" }
            @{ id = $users.'ops.steward'; contactType = "Expert" }
        )
    },
    @{
        name = "Data Platform Health"
        description = "Fabric pipeline status, data freshness scores, catalog completeness, query latency, refresh failure rates. The operations dashboard for the data platform team."
        domainId = $domMap["Technology and Data Platform"]
        owners = @(
            @{ id = $users.'tech.owner'; contactType = "Owner" }
            @{ id = $users.'tech.steward'; contactType = "Expert" }
            @{ id = $users.'data.architect'; contactType = "Expert" }
        )
    }
)

foreach ($dp in $dataProducts) {
    $body = @{
        name        = $dp.name
        description = $dp.description
        domainId    = $dp.domainId
        status      = "Published"
        contacts    = $dp.owners
    } | ConvertTo-Json -Depth 5
    
    $r = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts?api-version=$ucApi" `
        -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck
    
    if ($r.StatusCode -in 200,201) {
        $created = $r.Content | ConvertFrom-Json
        Write-Host "  + $($dp.name) — OK ($($created.id))"
    } else {
        Write-Host "  X $($dp.name) — $($r.StatusCode): $($r.Content)" -ForegroundColor Red
    }
}

Write-Host "`n========================================"
Write-Host " PHASE 2 — CREATE BUSINESS PROCESSES"
Write-Host "========================================`n"

# Business Processes via Atlas API (Purview_BusinessProcess)
$bizProcesses = @(
    @{
        name = "Order to Cash"
        description = "End-to-end process from customer order placement through invoicing and payment collection. Spans CRM, SAP, and financial reporting systems."
        collection = "hklbqp"
    },
    @{
        name = "Procure to Pay"
        description = "Procurement lifecycle from purchase requisition through supplier payment. Covers vendor management, purchase orders, goods receipt, and invoice verification."
        collection = "hklbqp"
    },
    @{
        name = "Hire to Retire"
        description = "Employee lifecycle from recruitment and onboarding through career development, compensation management, and offboarding."
        collection = "hklbqp"
    },
    @{
        name = "Plan to Report"
        description = "Financial planning, budgeting, forecasting, and statutory reporting cycle. Includes month-end close, consolidation, and ESG/CSRD reporting."
        collection = "hklbqp"
    },
    @{
        name = "Equipment to Maintenance"
        description = "Asset lifecycle from commissioning through preventive and corrective maintenance, inspection, and decommissioning. Driven by SAP PM and RAMSES."
        collection = "hklbqp"
    }
)

foreach ($bp in $bizProcesses) {
    $body = @{
        entity = @{
            typeName   = "Purview_BusinessProcess"
            attributes = @{
                name            = $bp.name
                description     = $bp.description
                qualifiedName   = "purview_business_process://$($bp.name.ToLower().Replace(' ','_'))"
            }
            collectionId = $bp.collection
        }
    } | ConvertTo-Json -Depth 5

    $r = Invoke-WebRequest "$base/catalog/api/atlas/v2/entity?api-version=$atlasApi" `
        -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck

    if ($r.StatusCode -in 200,201) {
        $guid = ($r.Content | ConvertFrom-Json).guidAssignments.PSObject.Properties.Value
        if (-not $guid) { $guid = ($r.Content | ConvertFrom-Json).mutatedEntities.CREATE[0].guid }
        Write-Host "  + $($bp.name) — OK ($guid)"
    } else {
        Write-Host "  X $($bp.name) — $($r.StatusCode): $($r.Content)" -ForegroundColor Red
    }
}

Write-Host "`n========================================"
Write-Host " PHASE 3 — RENAME COLLECTIONS"
Write-Host "========================================`n"

$collRenames = @(
    @{ name = "hklbqp"; friendlyName = "Enterprise Analytics" }
    @{ name = "242twh"; friendlyName = "Cloud Databases" }
    @{ name = "fmjxwb"; friendlyName = "Company B" }
    @{ name = "vwo17u"; friendlyName = "On-Premises Systems" }
    @{ name = "7qip1a"; friendlyName = "Dynamics and Dataverse" }
    @{ name = "kdlaul"; friendlyName = "AWS Sources" }
    @{ name = "bpnc43"; friendlyName = "Salesforce" }
    @{ name = "6zun08"; friendlyName = "SAP LIFT" }
    @{ name = "jtecfo"; friendlyName = "RC Applications" }
    @{ name = "ozssv7"; friendlyName = "PREPROD POC" }
    @{ name = "9eabrc"; friendlyName = "GCP Sources" }
)

foreach ($c in $collRenames) {
    # GET current collection to preserve parentCollection
    $cur = Invoke-WebRequest "$base/account/collections/$($c.name)?api-version=2019-11-01-preview" `
        -Headers $headers -SkipHttpErrorCheck
    
    if ($cur.StatusCode -eq 200) {
        $coll = $cur.Content | ConvertFrom-Json
        $body = @{
            friendlyName     = $c.friendlyName
            parentCollection = @{ referenceName = $coll.parentCollection.referenceName }
        } | ConvertTo-Json -Depth 3
        
        $r = Invoke-WebRequest "$base/account/collections/$($c.name)?api-version=2019-11-01-preview" `
            -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
        
        if ($r.StatusCode -eq 200) {
            Write-Host "  + $($c.name) -> '$($c.friendlyName)' — OK"
        } else {
            Write-Host "  X $($c.name) — $($r.StatusCode): $($r.Content)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ? $($c.name) — GET $($cur.StatusCode)" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================"
Write-Host " PHASE 4 — DATA QUALITY RULES (probe)"
Write-Host "========================================`n"

# Probe DQ endpoints to see if we have access now
$dqEndpoints = @(
    "$base/datagovernance/catalog/dataquality/rulesets?api-version=$ucApi"
    "$base/datagovernance/catalog/dataqualityrules?api-version=$ucApi"
)

foreach ($ep in $dqEndpoints) {
    $r = Invoke-WebRequest $ep -Headers $headers -SkipHttpErrorCheck
    Write-Host "  $($ep.Split('/')[-1].Split('?')[0]): $($r.StatusCode)"
}

Write-Host "`n========================================"
Write-Host " PHASE 5 — LINK TERMS TO ASSETS (sample)"
Write-Host "========================================`n"

# Find some Power BI datasets and link relevant glossary terms
# First, get a few PBI dataset GUIDs
$searchBody = @{
    keywords = "*"
    filter   = @{ entityType = "powerbi_dataset" }
    limit    = 10
} | ConvertTo-Json -Depth 3

$pbiAssets = (Invoke-RestMethod "$base/catalog/api/search/query?api-version=$atlasApi" `
    -Headers $headers -Method Post -Body $searchBody).value

Write-Host "Found $($pbiAssets.Count) PBI datasets to sample"

# Get UC terms to find IDs
$ucTerms = (Invoke-RestMethod "$base/datagovernance/catalog/terms?api-version=$ucApi" -Headers $headers).value

# Find existing Atlas glossary terms that we can link via meanings
$atlasSearchBody = @{
    keywords = "*"
    filter   = @{ entityType = "AtlasGlossaryTerm" }
    limit    = 50
} | ConvertTo-Json -Depth 3
$atlasTerms = (Invoke-RestMethod "$base/catalog/api/search/query?api-version=$atlasApi" `
    -Headers $headers -Method Post -Body $atlasSearchBody).value

Write-Host "Atlas glossary terms available: $($atlasTerms.Count)"
if ($atlasTerms.Count -gt 0) {
    # Try to link first 3 PBI datasets with "Revenue" term if it exists
    $revTerm = $atlasTerms | Where-Object { $_.name -eq "Revenue" } | Select-Object -First 1
    if ($revTerm -and $pbiAssets.Count -gt 0) {
        $asset = $pbiAssets[0]
        Write-Host "  Linking '$($asset.name)' <- 'Revenue' term..."
        
        # Get full entity to get existing meanings
        $entity = Invoke-RestMethod "$base/catalog/api/atlas/v2/entity/guid/$($asset.id)?api-version=$atlasApi" -Headers $headers
        
        $termRef = @{
            typeName = "AtlasGlossaryTerm"
            guid = $revTerm.id
        }
        
        # Add meaning via dedicated endpoint
        $meaningBody = @( $termRef ) | ConvertTo-Json -Depth 3
        $r = Invoke-WebRequest "$base/catalog/api/atlas/v2/entity/guid/$($asset.id)/terms?api-version=$atlasApi" `
            -Headers $headers -Method POST -Body $meaningBody -SkipHttpErrorCheck
        Write-Host "  Result: $($r.StatusCode)"
    } else {
        Write-Host "  No 'Revenue' term found or no PBI assets to link" -ForegroundColor Yellow
    }
    
    # Link a few more if we find matching terms
    $termAssetPairs = @(
        @{ termName = "EBITDA";     assetPattern = "financ" }
        @{ termName = "Headcount";  assetPattern = "hr|employee|workforce" }
        @{ termName = "OEE";        assetPattern = "operat|equipment|asset" }
        @{ termName = "NPS";        assetPattern = "customer|crm|sales" }
    )
    
    foreach ($pair in $termAssetPairs) {
        $term = $atlasTerms | Where-Object { $_.name -eq $pair.termName } | Select-Object -First 1
        if ($term) {
            # Search for matching asset
            $sBody = @{ keywords = $pair.assetPattern.Split('|')[0]; limit = 3 } | ConvertTo-Json
            $matches = (Invoke-RestMethod "$base/catalog/api/search/query?api-version=$atlasApi" `
                -Headers $headers -Method Post -Body $sBody).value | Select-Object -First 1
            if ($matches) {
                $mBody = @( @{ typeName = "AtlasGlossaryTerm"; guid = $term.id } ) | ConvertTo-Json -Depth 3
                $r = Invoke-WebRequest "$base/catalog/api/atlas/v2/entity/guid/$($matches.id)/terms?api-version=$atlasApi" `
                    -Headers $headers -Method POST -Body $mBody -SkipHttpErrorCheck
                Write-Host "  + '$($matches.name)' <- '$($pair.termName)': $($r.StatusCode)"
            }
        }
    }
} else {
    Write-Host "  No Atlas glossary terms found — skipping term linking" -ForegroundColor Yellow
}

Write-Host "`n========================================"
Write-Host " PHASE 6 — GHOST CLEANUP STATUS"
Write-Host "========================================`n"

# Check if ghosts have cleared
$doms2 = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?api-version=$ucApi" -Headers $headers).value
$dps2 = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?api-version=$ucApi" -Headers $headers).value
$ghostD = ($doms2 | Where-Object { $_.name -notin $ourNames -and $_.name -notin $dataProducts.name }).Count
$ourD = ($doms2 | Where-Object { $_.name -in $ourNames }).Count

# Redefine ourNames to include our names
$ourNames = @("Finance and ESG","Customer and Sales","HR and People","Operations and Industrial","Technology and Data Platform","Accounting and Reporting","Treasury and Risk","ESG and Sustainability","CRM and Customer Data","Commercial Analytics","Talent Management","Workforce Analytics","Industrial Assets","Supply Chain and Logistics","Data Engineering","BI and Analytics")
$ourDPNames = @("Executive Financial Dashboards","ESG and CSRD Reporting Pack","Customer 360","Workforce Analytics","Operational Performance Hub","Data Platform Health")
$ghostDPNames = @("Convergence B2B","RC Datahub Inspection","New data product TDF","Books Analytics &  Forecasting")

$ghostDoms = ($doms2 | Where-Object { $_.name -notin $ourNames }).Count
$ghostDPs = ($dps2 | Where-Object { $_.name -in $ghostDPNames }).Count
$newDPs = ($dps2 | Where-Object { $_.name -in $ourDPNames }).Count

Write-Host "Domains:  $ourD ours + $ghostDoms ghosts = $($doms2.Count) total"
Write-Host "Products: $newDPs ours + $ghostDPs ghosts = $($dps2.Count) total"
if ($ghostDoms -gt 0 -or $ghostDPs -gt 0) {
    Write-Host "  Ghosts still present (Atlas cache lag — will resolve)" -ForegroundColor Yellow
} else {
    Write-Host "  All clean!" -ForegroundColor Green
}

Write-Host "`n========================================"
Write-Host " PHASE 7 — FINAL VERIFICATION"
Write-Host "========================================`n"

# List our full hierarchy
$allDoms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?api-version=$ucApi" -Headers $headers).value
$allTerms = (Invoke-RestMethod "$base/datagovernance/catalog/terms?api-version=$ucApi" -Headers $headers).value
$allDPs = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?api-version=$ucApi" -Headers $headers).value

Write-Host "Domain Hierarchy:"
$allDoms | Where-Object { $_.name -in $ourNames -and (-not $_.parentId -or $_.parentId -notin ($allDoms | Where-Object { $_.name -in $ourNames }).id) } | Sort-Object name | ForEach-Object {
    Write-Host "  $($_.name) [$($_.type)]"
    $pid1 = $_.id
    $allDoms | Where-Object { $_.parentId -eq $pid1 } | Sort-Object name | ForEach-Object {
        $domTerms = ($allTerms | Where-Object { $_.domainId -eq $_.id }).Count
        Write-Host "    +-- $($_.name) ($domTerms terms)"
    }
}

Write-Host "`nData Products:"
$allDPs | Where-Object { $_.name -in $ourDPNames } | ForEach-Object {
    $domName = ($allDoms | Where-Object { $_.id -eq $_.domainId }).name
    Write-Host "  $($_.name) -> domain: $domName"
}

# Business processes
$bpSearch = @{ keywords = "*"; filter = @{ entityType = "Purview_BusinessProcess" }; limit = 20 } | ConvertTo-Json -Depth 3
$bps = (Invoke-RestMethod "$base/catalog/api/search/query?api-version=$atlasApi" -Headers $headers -Method Post -Body $bpSearch).value
Write-Host "`nBusiness Processes: $($bps.Count)"
$bps | ForEach-Object { Write-Host "  $($_.name)" }

Write-Host "`n========================================"
Write-Host " SUMMARY"
Write-Host "========================================"
Write-Host "  UC Domains      : $ourD"
Write-Host "  UC Terms         : $($allTerms.Count)"
Write-Host "  UC Data Products : $newDPs"
Write-Host "  Biz Processes    : $($bps.Count)"
Write-Host "  Ghost domains    : $ghostDoms"
Write-Host "  Ghost DPs        : $ghostDPs"
Write-Host "========================================"
