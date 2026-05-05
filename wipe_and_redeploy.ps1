# =============================================================================
# WIPE & REDEPLOY — Unified Catalog (Enterprise Glossary)
# =============================================================================
# 1. Delete ALL terms (must go before domains)
# 2. Delete ALL business domains
# 3. Recreate hierarchy: Root → Lines of Business → Data Domains (sub-domains)
# 4. Create glossary terms inside sub-domains
# 5. Assign demo user contacts (owner / steward / CDO)
#
# Data Map objects are NOT touched.
# =============================================================================

$ErrorActionPreference = "Continue"
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$base    = "https://pdedemopurv.purview.azure.com"
$api     = "api-version=2026-03-20-preview"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 1 — DELETE ALL TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# List all domains first
$doms = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Get).value
Write-Host "Domains found: $($doms.Count)"

$termDelOk = 0; $termDelKo = 0
foreach ($d in $doms) {
    try {
        $terms = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=200" -Headers $headers -Method Get -ErrorAction Stop).value
    } catch { continue }
    if ($terms.Count -eq 0) { continue }
    Write-Host "  Domain '$($d.name)' — $($terms.Count) terms to delete"
    foreach ($t in $terms) {
        try {
            Invoke-RestMethod -Uri "$base/datagovernance/catalog/terms/$($t.id)?$api" -Headers $headers -Method Delete -ErrorAction Stop | Out-Null
            $termDelOk++; Write-Host "    DEL $($t.name) — OK" -ForegroundColor Green
        } catch {
            $termDelKo++; Write-Host "    DEL $($t.name) — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        }
    }
}
Write-Host "Terms deleted: $termDelOk OK / $termDelKo FAIL" -ForegroundColor $(if($termDelKo -eq 0){"Green"}else{"Yellow"})

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 2 — DELETE ALL DOMAINS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Delete children first (domains with parentId), then parents
$children = $doms | Where-Object { $_.parentId }
$parents  = $doms | Where-Object { -not $_.parentId }

$domDelOk = 0; $domDelKo = 0
foreach ($d in ($children + $parents)) {
    Write-Host "  DEL domain '$($d.name)' [$($d.type)]..." -NoNewline
    try {
        Invoke-RestMethod -Uri "$base/datagovernance/catalog/businessdomains/$($d.id)?$api" -Headers $headers -Method Delete -ErrorAction Stop | Out-Null
        $domDelOk++; Write-Host " OK" -ForegroundColor Green
    } catch {
        $domDelKo++; Write-Host " FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
    }
}
Write-Host "Domains deleted: $domDelOk OK / $domDelKo FAIL" -ForegroundColor $(if($domDelKo -eq 0){"Green"}else{"Yellow"})

# Verify clean state
$remaining = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Get).value
Write-Host "`nRemaining domains: $($remaining.Count)" -ForegroundColor $(if($remaining.Count -eq 0){"Green"}else{"Red"})
if ($remaining.Count -gt 0) {
    $remaining | ForEach-Object { Write-Host "  STILL: $($_.name) [$($_.type)] id=$($_.id)" -ForegroundColor Red }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 3 — CREATE DOMAIN HIERARCHY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Demo user OIDs ---
$users = Get-Content "$PSScriptRoot\demo_users.json" | ConvertFrom-Json
$pierreOid = "0738cec4-3dd2-4d28-86bc-9585d85eb511"

function New-Domain($name, $desc, $type, $color, $parentId) {
    $id = [guid]::NewGuid().ToString()
    $body = @{
        id = $id; name = $name; description = $desc
        status = "PUBLISHED"; type = $type; isRestricted = $false
        thumbnail = @{ color = $color }
        domains = @(); managedAttributes = @()
    }
    if ($parentId) { $body["parentId"] = $parentId }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod -Uri "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
        Write-Host "  + $name [$type] — OK (id=$($r.id))" -ForegroundColor Green
        return $r.id
    } catch {
        Write-Host "  + $name [$type] — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        return $null
    }
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  L1: Root — TTE Group (FunctionalUnit)                     ║
# ╚══════════════════════════════════════════════════════════════╝
$rootId = New-Domain "TTE Group" "Root governance domain for TTE industrial group — energy, chemicals, and services." "FunctionalUnit" "#1B2631" $null

# ╔══════════════════════════════════════════════════════════════╗
# ║  L2: Lines of Business (under Root)                        ║
# ╚══════════════════════════════════════════════════════════════╝
$finLobId  = New-Domain "Finance and ESG"             "Financial reporting, ESG metrics, CSRD compliance, treasury and accounting." "LineOfBusiness" "#2E86C1" $rootId
$custLobId = New-Domain "Customer and Sales"          "Customer 360, CRM, sales pipeline, B2B/B2C segmentation."                  "LineOfBusiness" "#27AE60" $rootId
$hrLobId   = New-Domain "HR and People"               "Workforce analytics, talent management, payroll, engagement."              "LineOfBusiness" "#8E44AD" $rootId
$opsLobId  = New-Domain "Operations and Industrial"   "Operational performance, industrial assets, supply chain, maintenance."    "LineOfBusiness" "#E67E22" $rootId
$techLobId = New-Domain "Technology and Data Platform" "Data platform health, data quality, infrastructure, BI & analytics."      "LineOfBusiness" "#2C3E50" $rootId

# ╔══════════════════════════════════════════════════════════════╗
# ║  L3: Data Domains (sub-domains under each LoB)             ║
# ╚══════════════════════════════════════════════════════════════╝

# --- Finance sub-domains ---
$finAcct   = New-Domain "Accounting and Reporting" "General ledger, P&L, balance sheet, statutory and management reporting."       "DataDomain" "#3498DB" $finLobId
$finTreas  = New-Domain "Treasury and Risk"        "Cash management, FX exposure, financial risk, credit and liquidity."            "DataDomain" "#5DADE2" $finLobId
$finEsg    = New-Domain "ESG and Sustainability"   "Carbon footprint, CSRD compliance, ESG scores, environmental KPIs."            "DataDomain" "#1ABC9C" $finLobId

# --- Customer sub-domains ---
$custCrm   = New-Domain "CRM and Customer Data"   "Customer master, contact management, segmentation, consent and preferences."   "DataDomain" "#2ECC71" $custLobId
$custComm  = New-Domain "Commercial Analytics"     "Sales pipeline, forecasting, pricing, market share, channel performance."      "DataDomain" "#58D68D" $custLobId

# --- HR sub-domains ---
$hrTalent  = New-Domain "Talent Management"        "Recruitment, onboarding, career development, succession planning."             "DataDomain" "#9B59B6" $hrLobId
$hrWork    = New-Domain "Workforce Analytics"      "Headcount, turnover, absenteeism, compensation benchmarking."                  "DataDomain" "#AF7AC5" $hrLobId

# --- Operations sub-domains ---
$opsAsset  = New-Domain "Industrial Assets"        "Equipment registry, maintenance, inspections, corrosion, predictive analytics." "DataDomain" "#E74C3C" $opsLobId
$opsSC     = New-Domain "Supply Chain and Logistics" "Procurement, inventory, warehousing, transport, supplier performance."       "DataDomain" "#F39C12" $opsLobId

# --- Technology sub-domains ---
$techDE    = New-Domain "Data Engineering"         "Pipelines, data quality, lineage, schema management, ingestion."               "DataDomain" "#34495E" $techLobId
$techBI    = New-Domain "BI and Analytics"          "Reports, dashboards, usage analytics, self-service BI governance."             "DataDomain" "#566573" $techLobId

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 4 — CREATE GLOSSARY TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Contact mapping: sub-domain → owner OID, steward OID
$contactMap = @{
    $finAcct   = @{ owner = $users.'financeowner';    steward = $users.'financesteward' }
    $finTreas  = @{ owner = $users.'financeowner';    steward = $users.'financesteward' }
    $finEsg    = @{ owner = $users.'financeowner';    steward = $users.'financesteward' }
    $custCrm   = @{ owner = $users.'customer.owner';  steward = $users.'customer.steward' }
    $custComm  = @{ owner = $users.'customer.owner';  steward = $users.'customer.steward' }
    $hrTalent  = @{ owner = $users.'hr.owner';        steward = $users.'hr.steward' }
    $hrWork    = @{ owner = $users.'hr.owner';        steward = $users.'hr.steward' }
    $opsAsset  = @{ owner = $users.'ops.owner';       steward = $users.'ops.steward' }
    $opsSC     = @{ owner = $users.'ops.owner';       steward = $users.'ops.steward' }
    $techDE    = @{ owner = $users.'tech.owner';      steward = $users.'tech.steward' }
    $techBI    = @{ owner = $users.'tech.owner';      steward = $users.'tech.steward' }
}

function New-Term($name, $desc, $domainId, $acronyms) {
    $c = $contactMap[$domainId]
    $body = @{
        id = [guid]::NewGuid().ToString(); name = $name; description = $desc
        status = "PUBLISHED"; domain = $domainId
        contacts = @{
            owner  = @( @{ id = $c.owner;         description = "Data Owner" } )
            expert = @( @{ id = $c.steward;        description = "Data Steward" },
                        @{ id = $users.'cdo';      description = "Chief Data Officer" } )
        }
    }
    if ($acronyms) { $body["acronyms"] = $acronyms }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod -Uri "$base/datagovernance/catalog/terms?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
        Write-Host "    + $name — OK" -ForegroundColor Green
        return $r.id
    } catch {
        Write-Host "    + $name — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        return $null
    }
}

# ── Accounting and Reporting ──
Write-Host "`n  Sub-domain: Accounting and Reporting" -ForegroundColor Yellow
New-Term "Revenue"              "Total income generated from business activities before expenses."                          $finAcct $null
New-Term "EBITDA"               "Earnings Before Interest, Taxes, Depreciation, and Amortization."                         $finAcct @("EBITDA")
New-Term "Net Income"           "Total profit after all expenses, taxes and costs have been deducted from revenue."         $finAcct $null
New-Term "Cost Center"          "Organizational unit that incurs costs but does not directly generate revenue."             $finAcct $null
New-Term "Budget Variance"      "Difference between budgeted and actual financial performance."                             $finAcct $null
New-Term "Chart of Accounts"    "Structured list of all accounts used in the general ledger."                              $finAcct @("CoA")
New-Term "Intercompany"         "Transactions between legal entities within the same corporate group."                     $finAcct @("IC")

# ── Treasury and Risk ──
Write-Host "  Sub-domain: Treasury and Risk" -ForegroundColor Yellow
New-Term "Cash Position"        "Current cash and cash equivalents available across all bank accounts."                     $finTreas $null
New-Term "FX Exposure"          "Financial risk arising from fluctuations in foreign exchange rates."                       $finTreas @("FX")
New-Term "Credit Rating"        "Assessment of creditworthiness of a counterparty or instrument."                          $finTreas $null
New-Term "Value at Risk"        "Statistical measure of the maximum potential loss over a given time horizon."             $finTreas @("VaR")

# ── ESG and Sustainability ──
Write-Host "  Sub-domain: ESG and Sustainability" -ForegroundColor Yellow
New-Term "Carbon Footprint"     "Total greenhouse gas emissions in CO2 equivalent (Scope 1, 2, 3)."                        $finEsg $null
New-Term "ESG Score"            "Composite rating measuring Environmental, Social and Governance performance."             $finEsg @("ESG")
New-Term "CSRD Compliance"      "Adherence to Corporate Sustainability Reporting Directive requirements."                  $finEsg @("CSRD")
New-Term "Scope 1 Emissions"    "Direct GHG emissions from owned or controlled sources."                                  $finEsg $null
New-Term "Scope 2 Emissions"    "Indirect GHG emissions from purchased energy."                                           $finEsg $null
New-Term "Water Intensity"      "Water consumption per unit of production or revenue."                                     $finEsg $null

# ── CRM and Customer Data ──
Write-Host "  Sub-domain: CRM and Customer Data" -ForegroundColor Yellow
New-Term "Customer ID"          "Unique identifier assigned to each customer across all systems."                           $custCrm $null
New-Term "Customer Lifetime Value" "Predicted net profit from the entire future relationship with a customer."             $custCrm @("CLV","CLTV")
New-Term "Net Promoter Score"   "Metric measuring customer loyalty and satisfaction on a -100 to +100 scale."              $custCrm @("NPS")
New-Term "Churn Rate"           "Percentage of customers who stop using a service during a given period."                  $custCrm $null
New-Term "Customer Segment"     "Distinct group of customers sharing similar characteristics or needs."                    $custCrm $null
New-Term "GDPR Consent Status"  "Whether a customer has given, refused, or withdrawn data processing consent."             $custCrm @("GDPR")

# ── Commercial Analytics ──
Write-Host "  Sub-domain: Commercial Analytics" -ForegroundColor Yellow
New-Term "Sales Pipeline"       "Visual representation of sales prospects and their stage in the buying process."           $custComm $null
New-Term "Lead Conversion Rate" "Percentage of leads that become paying customers."                                        $custComm $null
New-Term "Average Order Value"  "Mean monetary value of each customer order."                                              $custComm @("AOV")
New-Term "Win Rate"             "Percentage of proposals or bids that result in closed deals."                             $custComm $null
New-Term "Market Share"         "Percentage of total market revenue captured by the company."                              $custComm $null

# ── Talent Management ──
Write-Host "  Sub-domain: Talent Management" -ForegroundColor Yellow
New-Term "Employee ID"          "Unique identifier for each employee in the HR system."                                    $hrTalent $null
New-Term "Time to Hire"         "Average number of days from job posting to candidate acceptance."                         $hrTalent $null
New-Term "Training Hours"       "Total hours of professional development and training per employee."                       $hrTalent $null
New-Term "Succession Readiness" "Percentage of critical roles with at least one identified successor."                     $hrTalent $null
New-Term "Engagement Score"     "Quantitative measure of employee satisfaction and commitment."                            $hrTalent $null

# ── Workforce Analytics ──
Write-Host "  Sub-domain: Workforce Analytics" -ForegroundColor Yellow
New-Term "Headcount"            "Total number of active employees at a given point in time."                               $hrWork @("FTE")
New-Term "Turnover Rate"        "Percentage of employees leaving the organization during a specified period."              $hrWork $null
New-Term "Absenteeism Rate"     "Percentage of scheduled workdays lost due to employee absence."                           $hrWork $null
New-Term "Compensation Band"    "Salary range bracket assigned to a job grade or position level."                          $hrWork $null
New-Term "Gender Pay Gap"       "Difference in average earnings between male and female employees."                        $hrWork $null

# ── Industrial Assets ──
Write-Host "  Sub-domain: Industrial Assets" -ForegroundColor Yellow
New-Term "Equipment ID"         "Unique identifier for industrial equipment and physical assets."                           $opsAsset $null
New-Term "OEE"                  "Overall Equipment Effectiveness — availability x performance x quality."                  $opsAsset @("OEE")
New-Term "MTBF"                 "Mean Time Between Failures — average time between equipment breakdowns."                  $opsAsset @("MTBF")
New-Term "Downtime"             "Period when equipment or a system is not operational."                                    $opsAsset $null
New-Term "Corrosion Loop"       "Defined circuit grouping equipment subject to similar corrosion mechanisms."              $opsAsset $null
New-Term "Safety Incident"      "Any unplanned event resulting in injury, illness or property damage."                     $opsAsset $null
New-Term "Production Yield"     "Percentage of output meeting quality standards from total production."                    $opsAsset $null

# ── Supply Chain and Logistics ──
Write-Host "  Sub-domain: Supply Chain and Logistics" -ForegroundColor Yellow
New-Term "Lead Time"            "Total time from order placement to delivery of goods."                                    $opsSC $null
New-Term "Inventory Turnover"   "Number of times inventory is sold and replaced over a period."                            $opsSC $null
New-Term "On-Time Delivery"     "Percentage of orders delivered by the committed date."                                    $opsSC @("OTD")
New-Term "Supplier Score"       "Composite rating of a supplier's quality, reliability and cost."                          $opsSC $null
New-Term "Procurement Spend"    "Total value of goods and services purchased in a given period."                           $opsSC $null

# ── Data Engineering ──
Write-Host "  Sub-domain: Data Engineering" -ForegroundColor Yellow
New-Term "Data Quality Score"   "Composite metric measuring accuracy, completeness, consistency and timeliness."           $techDE $null
New-Term "Data Freshness"       "Time elapsed since the last update of a dataset or pipeline run."                         $techDE $null
New-Term "Pipeline SLA"         "Service Level Agreement for data pipeline execution time and reliability."                $techDE @("SLA")
New-Term "Schema Drift"         "Unplanned changes to data structure that may break downstream consumers."                $techDE $null
New-Term "Data Lineage"         "End-to-end traceability of data from source to consumption."                              $techDE $null

# ── BI and Analytics ──
Write-Host "  Sub-domain: BI and Analytics" -ForegroundColor Yellow
New-Term "Active Users"         "Number of unique users who accessed a platform or report in a given period."              $techBI @("DAU","MAU")
New-Term "Report Adoption Rate" "Percentage of target audience actively using a published report."                         $techBI $null
New-Term "Query Latency"        "Time taken for a data query to execute and return results."                               $techBI $null
New-Term "Self-Service Ratio"   "Percentage of reports created by business users vs. central BI team."                     $techBI $null
New-Term "Refresh Failure Rate" "Percentage of scheduled dataset refreshes that fail in a given period."                   $techBI $null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 5 — VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$finalDoms = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Get).value
$l1 = $finalDoms | Where-Object { -not $_.parentId }
$l2 = $finalDoms | Where-Object { $_.parentId -and $_.type -eq "LineOfBusiness" }
$l3 = $finalDoms | Where-Object { $_.parentId -and $_.type -eq "DataDomain" }

Write-Host "`nDomain hierarchy:" -ForegroundColor White
foreach ($root in $l1) {
    Write-Host "  $($root.name) [$($root.type)]" -ForegroundColor Cyan
    $kids = $l2 | Where-Object { $_.parentId -eq $root.id }
    foreach ($lob in $kids) {
        Write-Host "    +-- $($lob.name) [$($lob.type)]" -ForegroundColor Yellow
        $subs = $l3 | Where-Object { $_.parentId -eq $lob.id }
        foreach ($dd in $subs) {
            Write-Host "        +-- $($dd.name) [$($dd.type)]" -ForegroundColor Green
        }
    }
}

# Count terms
$totalTerms = 0
foreach ($d in $finalDoms) {
    try {
        $t = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=200" -Headers $headers -Method Get -ErrorAction Stop).value
        $totalTerms += $t.Count
    } catch {}
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deleted  : $domDelOk domains + $termDelOk terms"
Write-Host "  Created  : $($finalDoms.Count) domains ($($l1.Count) root + $($l2.Count) LoB + $($l3.Count) sub-domains)"
Write-Host "  Terms    : $totalTerms glossary terms with owner/steward/CDO contacts"
Write-Host "  Hierarchy: 3 levels (Root > Line of Business > Data Domain)"
Write-Host "========================================" -ForegroundColor Cyan
