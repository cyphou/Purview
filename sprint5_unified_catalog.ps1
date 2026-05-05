# =============================================================================
# Sprint 5: Create Governance Objects via Unified Catalog API (2026-03-20-preview)
# =============================================================================
# This script creates Business Domains + Glossary Terms in the NEW Unified Catalog
# so they appear in the Enterprise Glossary (Preview) portal.
#
# API Reference:
#   https://learn.microsoft.com/en-us/rest/api/purview/purview-unified-catalog/operation-groups
#
# Endpoint: POST {endpoint}/datagovernance/catalog/businessdomains?api-version=2026-03-20-preview
#           POST {endpoint}/datagovernance/catalog/terms?api-version=2026-03-20-preview
# =============================================================================

$ErrorActionPreference = "Stop"

# --- Auth ---
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
if (-not $token) { Write-Error "Failed to get access token"; exit 1 }
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}
$baseUrl   = "https://pdedemopurv.purview.azure.com"
$apiVer    = "api-version=2026-03-20-preview"
$pierreOid = "0738cec4-3dd2-4d28-86bc-9585d85eb511"
$now       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Sprint 5 — Unified Catalog API" -ForegroundColor Cyan
Write-Host " Endpoint: $baseUrl" -ForegroundColor Cyan
Write-Host " API Version: 2026-03-20-preview" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# =============================================================================
# PHASE 1: Create 5 Governance Domains (DataDomain type)
# =============================================================================
Write-Host "`n=== PHASE 1: Create Business Domains ===" -ForegroundColor Yellow

$domains = @(
    @{
        id          = [guid]::NewGuid().ToString()
        name        = "Finance and ESG"
        description = "Financial reporting, accounting, treasury, ESG metrics, CSRD compliance and sustainability data governance."
        type        = "DataDomain"
        color       = "#2E86C1"
    },
    @{
        id          = [guid]::NewGuid().ToString()
        name        = "Customer and Sales"
        description = "Customer 360, sales pipeline, CRM data, B2B/B2C segmentation and commercial analytics."
        type        = "DataDomain"
        color       = "#27AE60"
    },
    @{
        id          = [guid]::NewGuid().ToString()
        name        = "HR and People"
        description = "Workforce analytics, talent management, payroll, employee engagement and organizational data."
        type        = "DataDomain"
        color       = "#8E44AD"
    },
    @{
        id          = [guid]::NewGuid().ToString()
        name        = "Operations and Industrial"
        description = "Operational performance, industrial assets, supply chain, maintenance and production data."
        type        = "DataDomain"
        color       = "#E67E22"
    },
    @{
        id          = [guid]::NewGuid().ToString()
        name        = "Technology and Data Platform"
        description = "Data platform health, infrastructure monitoring, data quality metrics and IT service management."
        type        = "DataDomain"
        color       = "#2C3E50"
    }
)

$domainResults = @{}
$domainOk = 0
$domainKo = 0

foreach ($d in $domains) {
    Write-Host "`n  Creating domain: $($d.name) [$($d.type)]..." -NoNewline
    
    $body = @{
        id               = $d.id
        name             = $d.name
        description      = $d.description
        status           = "PUBLISHED"
        type             = $d.type
        isRestricted     = $false
        thumbnail        = @{ color = $d.color }
        domains          = @()
        managedAttributes = @()
    } | ConvertTo-Json -Depth 5

    try {
        $resp = Invoke-WebRequest `
            -Uri "$baseUrl/datagovernance/catalog/businessdomains?$apiVer" `
            -Headers $headers -Method Post -Body $body -UseBasicParsing -ErrorAction Stop
        $created = $resp.Content | ConvertFrom-Json
        $domainResults[$d.name] = $created.id
        $domainOk++
        Write-Host " OK (id=$($created.id))" -ForegroundColor Green
    }
    catch {
        $status = $_.Exception.Response.StatusCode
        $errBody = $_.ErrorDetails.Message
        Write-Host " FAILED ($status)" -ForegroundColor Red
        Write-Host "    $errBody" -ForegroundColor DarkRed
        $domainKo++
        
        # If conflict (already exists), try to find existing domain
        if ($status -eq "Conflict") {
            Write-Host "    Domain may already exist, searching..." -ForegroundColor DarkYellow
        }
    }
}

Write-Host "`n  --- Domain Summary: $domainOk OK / $domainKo FAILED ---" -ForegroundColor $(if ($domainKo -eq 0) { "Green" } else { "Yellow" })

# Save domain GUIDs
$domainResults | ConvertTo-Json | Out-File -FilePath "sprint5_domain_guids.json" -Encoding utf8
Write-Host "  Domain GUIDs saved to sprint5_domain_guids.json" -ForegroundColor DarkGray

# =============================================================================
# PHASE 2: Create Glossary Terms (assigned to new domains)
# =============================================================================
Write-Host "`n=== PHASE 2: Create Glossary Terms ===" -ForegroundColor Yellow

# Build term definitions — each term references a domain ID
$terms = @()

# Finance and ESG terms
if ($domainResults["Finance and ESG"]) {
    $finDomainId = $domainResults["Finance and ESG"]
    $terms += @(
        @{ name = "Revenue";           domain = $finDomainId; description = "Total income generated from business activities before expenses." }
        @{ name = "EBITDA";            domain = $finDomainId; description = "Earnings Before Interest, Taxes, Depreciation, and Amortization."; acronyms = @("EBITDA") }
        @{ name = "Net Income";        domain = $finDomainId; description = "Total profit after all expenses, taxes and costs have been deducted from revenue." }
        @{ name = "Carbon Footprint";  domain = $finDomainId; description = "Total greenhouse gas emissions caused directly or indirectly, measured in CO2 equivalent." }
        @{ name = "ESG Score";         domain = $finDomainId; description = "Composite rating measuring Environmental, Social and Governance performance."; acronyms = @("ESG") }
        @{ name = "CSRD Compliance";   domain = $finDomainId; description = "Adherence to Corporate Sustainability Reporting Directive requirements."; acronyms = @("CSRD") }
        @{ name = "Cost Center";       domain = $finDomainId; description = "Organizational unit that incurs costs but does not directly generate revenue." }
        @{ name = "Budget Variance";   domain = $finDomainId; description = "Difference between budgeted and actual financial performance." }
    )
}

# Customer and Sales terms
if ($domainResults["Customer and Sales"]) {
    $custDomainId = $domainResults["Customer and Sales"]
    $terms += @(
        @{ name = "Customer ID";        domain = $custDomainId; description = "Unique identifier assigned to each customer across all systems." }
        @{ name = "Customer Lifetime Value"; domain = $custDomainId; description = "Predicted net profit from the entire future relationship with a customer."; acronyms = @("CLV", "CLTV") }
        @{ name = "Churn Rate";         domain = $custDomainId; description = "Percentage of customers who stop using a service during a given period." }
        @{ name = "Net Promoter Score"; domain = $custDomainId; description = "Metric measuring customer loyalty and satisfaction on a -100 to +100 scale."; acronyms = @("NPS") }
        @{ name = "Sales Pipeline";     domain = $custDomainId; description = "Visual representation of sales prospects and their stage in the buying process." }
        @{ name = "Lead Conversion Rate"; domain = $custDomainId; description = "Percentage of leads that become paying customers." }
        @{ name = "Average Order Value"; domain = $custDomainId; description = "Mean monetary value of each customer order."; acronyms = @("AOV") }
        @{ name = "Market Segment";     domain = $custDomainId; description = "Distinct group of customers sharing similar characteristics or needs." }
    )
}

# HR and People terms
if ($domainResults["HR and People"]) {
    $hrDomainId = $domainResults["HR and People"]
    $terms += @(
        @{ name = "Employee ID";        domain = $hrDomainId; description = "Unique identifier for each employee in the HR system." }
        @{ name = "Headcount";          domain = $hrDomainId; description = "Total number of active employees at a given point in time."; acronyms = @("FTE") }
        @{ name = "Turnover Rate";      domain = $hrDomainId; description = "Percentage of employees leaving the organization during a specified period." }
        @{ name = "Absenteeism Rate";   domain = $hrDomainId; description = "Percentage of scheduled workdays lost due to employee absence." }
        @{ name = "Training Hours";     domain = $hrDomainId; description = "Total hours of professional development and training per employee." }
        @{ name = "Compensation Band";  domain = $hrDomainId; description = "Salary range bracket assigned to a job grade or position level." }
        @{ name = "Engagement Score";   domain = $hrDomainId; description = "Quantitative measure of employee satisfaction and commitment." }
        @{ name = "Time to Hire";       domain = $hrDomainId; description = "Average number of days from job posting to candidate acceptance." }
    )
}

# Operations and Industrial terms
if ($domainResults["Operations and Industrial"]) {
    $opsDomainId = $domainResults["Operations and Industrial"]
    $terms += @(
        @{ name = "Equipment ID";       domain = $opsDomainId; description = "Unique identifier for industrial equipment and physical assets." }
        @{ name = "OEE";                domain = $opsDomainId; description = "Overall Equipment Effectiveness — composite metric of availability, performance and quality."; acronyms = @("OEE") }
        @{ name = "Mean Time Between Failures"; domain = $opsDomainId; description = "Average time between equipment breakdowns."; acronyms = @("MTBF") }
        @{ name = "Downtime";           domain = $opsDomainId; description = "Period when equipment or a system is not operational." }
        @{ name = "Production Yield";   domain = $opsDomainId; description = "Percentage of output meeting quality standards from total production." }
        @{ name = "Safety Incident";    domain = $opsDomainId; description = "Any unplanned event resulting in injury, illness or property damage." }
        @{ name = "Supply Chain Lead Time"; domain = $opsDomainId; description = "Total time from order placement to delivery of goods." }
        @{ name = "Inventory Turnover"; domain = $opsDomainId; description = "Number of times inventory is sold and replaced over a period." }
    )
}

# Technology and Data Platform terms
if ($domainResults["Technology and Data Platform"]) {
    $techDomainId = $domainResults["Technology and Data Platform"]
    $terms += @(
        @{ name = "Data Quality Score"; domain = $techDomainId; description = "Composite metric measuring accuracy, completeness, consistency and timeliness of data." }
        @{ name = "Data Freshness";     domain = $techDomainId; description = "Time elapsed since the last update of a dataset or data pipeline run." }
        @{ name = "Pipeline SLA";       domain = $techDomainId; description = "Service Level Agreement for data pipeline execution time and reliability."; acronyms = @("SLA") }
        @{ name = "Schema Drift";       domain = $techDomainId; description = "Unplanned changes to data structure that may break downstream consumers." }
        @{ name = "Data Lineage";       domain = $techDomainId; description = "End-to-end traceability of data from source to consumption." }
        @{ name = "API Latency";        domain = $techDomainId; description = "Time taken for an API request to be processed and return a response." }
        @{ name = "Storage Cost per TB"; domain = $techDomainId; description = "Monthly cost of storing one terabyte of data across cloud services." }
        @{ name = "Active Users";       domain = $techDomainId; description = "Number of unique users who accessed a platform or report in a given period."; acronyms = @("DAU", "MAU") }
    )
}

Write-Host "  Total terms to create: $($terms.Count)"
$termOk = 0
$termKo = 0
$termForbidden = $false

foreach ($t in $terms) {
    Write-Host "  Creating term: $($t.name)..." -NoNewline
    
    $termBody = @{
        id          = [guid]::NewGuid().ToString()
        name        = $t.name
        description = $t.description
        status      = "PUBLISHED"
        domain      = $t.domain
    }
    
    # Add optional fields
    if ($t.acronyms) { $termBody["acronyms"] = $t.acronyms }
    
    # Add owner contact
    $termBody["contacts"] = @{
        owner = @(
            @{ id = $pierreOid; description = "Data Steward" }
        )
    }
    
    $termJson = $termBody | ConvertTo-Json -Depth 5

    try {
        $resp = Invoke-WebRequest `
            -Uri "$baseUrl/datagovernance/catalog/terms?$apiVer" `
            -Headers $headers -Method Post -Body $termJson -UseBasicParsing -ErrorAction Stop
        $created = $resp.Content | ConvertFrom-Json
        $termOk++
        Write-Host " OK (id=$($created.id))" -ForegroundColor Green
    }
    catch {
        $status = $_.Exception.Response.StatusCode
        $errBody = $_.ErrorDetails.Message
        $termKo++
        
        if ($status -eq "Forbidden") {
            if (-not $termForbidden) {
                Write-Host " FORBIDDEN" -ForegroundColor Red
                Write-Host "    $errBody" -ForegroundColor DarkRed
                Write-Host "`n    *** Terms API requires additional Unified Catalog permissions ***" -ForegroundColor Red
                Write-Host "    Go to Purview portal > Data Governance > Roles and permissions" -ForegroundColor Red
                Write-Host "    Assign 'Governance Domain Curator' or equivalent role to your account." -ForegroundColor Red
                $termForbidden = $true
            } else {
                Write-Host " FORBIDDEN (same perm issue)" -ForegroundColor Red
            }
            # Stop trying after first Forbidden — all will fail
            if ($termForbidden -and $termKo -ge 2) {
                Write-Host "`n  Stopping term creation — permission issue affects all terms." -ForegroundColor Red
                break
            }
        }
        else {
            Write-Host " FAILED ($status)" -ForegroundColor Red
            Write-Host "    $errBody" -ForegroundColor DarkRed
        }
    }
}

Write-Host "`n  --- Term Summary: $termOk OK / $termKo FAILED ---" -ForegroundColor $(if ($termKo -eq 0) { "Green" } else { "Yellow" })

# =============================================================================
# PHASE 3: Verify — List all domains and terms
# =============================================================================
Write-Host "`n=== PHASE 3: Verification ===" -ForegroundColor Yellow

Write-Host "`n  Listing all business domains..."
try {
    $allDomains = Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/businessdomains?$apiVer" -Headers $headers -Method Get
    Write-Host "  Total domains in Unified Catalog: $($allDomains.value.Count)" -ForegroundColor Cyan
    
    # Highlight newly created
    foreach ($d in $allDomains.value) {
        $marker = if ($domainResults.Values -contains $d.id) { " [NEW]" } else { "" }
        Write-Host "    - $($d.name) [$($d.type)] status=$($d.status)$marker" -ForegroundColor $(if ($marker) { "Green" } else { "White" })
    }
} catch {
    Write-Host "  Failed to list domains: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " Sprint 5 — RESULTS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Domains created : $domainOk / $($domains.Count)" -ForegroundColor $(if ($domainOk -eq $domains.Count) { "Green" } else { "Yellow" })
Write-Host "  Terms created   : $termOk / $($terms.Count)" -ForegroundColor $(if ($termOk -eq $terms.Count) { "Green" } else { "Yellow" })

if ($termForbidden) {
    Write-Host "`n  ACTION REQUIRED:" -ForegroundColor Red
    Write-Host "  The Terms API returned 403 Forbidden." -ForegroundColor Red
    Write-Host "  You need to assign Unified Catalog governance roles:" -ForegroundColor Red
    Write-Host "  1. Go to https://app.purview.microsoft.com" -ForegroundColor White
    Write-Host "  2. Navigate to Settings > Roles and permissions" -ForegroundColor White
    Write-Host "  3. Add your account as 'Governance Domain Curator'" -ForegroundColor White
    Write-Host "  4. Re-run this script after role propagation (~5 min)" -ForegroundColor White
}

Write-Host "`n  Check Enterprise Glossary portal:" -ForegroundColor White
Write-Host "  https://app.purview.microsoft.com/data-governance/glossary" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
