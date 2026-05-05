# =============================================================================
# FIX DELETE & REDEPLOY — Unified Catalog (Enterprise Glossary)
# =============================================================================
# Problem: Published terms/domains can't be deleted directly (BadRequest).
#          Old Atlas domains return Forbidden (different API surface).
# Fix:     1. Unpublish (PUT status=Draft) → then DELETE
#          2. Skip old Atlas domains (must be deleted from portal)
#          3. Recreate correct hierarchy with parentIds
# =============================================================================

$ErrorActionPreference = "Continue"
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$base    = "https://pdedemopurv.purview.azure.com"
$api     = "api-version=2026-03-20-preview"
$myOid   = "0738cec4-3dd2-4d28-86bc-9585d85eb511"

# ── Helper: Unpublish then Delete a term ──
function Remove-Term($termId, $termName, $domainId) {
    # Step 1: PUT to Draft
    $body = @{ status = "Draft"; name = $termName; description = "."; domain = $domainId } | ConvertTo-Json
    $r = Invoke-WebRequest "$base/datagovernance/catalog/terms/${termId}?$api" -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
    if ($r.StatusCode -ne 200) {
        Write-Host "    UNPUBLISH $termName — FAIL ($($r.StatusCode))" -ForegroundColor Red
        return $false
    }
    # Step 2: DELETE
    $r2 = Invoke-WebRequest "$base/datagovernance/catalog/terms/${termId}?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
    if ($r2.StatusCode -in 200,204) {
        Write-Host "    DEL $termName — OK" -ForegroundColor Green
        return $true
    } else {
        Write-Host "    DEL $termName — FAIL ($($r2.StatusCode) $($r2.Content))" -ForegroundColor Red
        return $false
    }
}

# ── Helper: Unpublish then Delete a domain ──
function Remove-Domain($domId, $domName) {
    # Step 1: Try to add ourselves as owner + set to Draft
    $getR = Invoke-WebRequest "$base/datagovernance/catalog/businessdomains/${domId}?$api" -Headers $headers -Method GET -SkipHttpErrorCheck
    if ($getR.StatusCode -ne 200) {
        Write-Host "  GET $domName — FAIL ($($getR.StatusCode))" -ForegroundColor Red
        return $false
    }
    $existing = $getR.Content | ConvertFrom-Json
    $body = @{
        status = "Draft"; name = $existing.name; type = $existing.type
        description = if ($existing.description) { $existing.description } else { "." }
        contacts = @{ owner = @(@{ id = $myOid; description = "Admin" }) }
    }
    if ($existing.parentId) { $body["parentId"] = $existing.parentId }
    $json = $body | ConvertTo-Json -Depth 4
    $r = Invoke-WebRequest "$base/datagovernance/catalog/businessdomains/${domId}?$api" -Headers $headers -Method PUT -Body $json -SkipHttpErrorCheck
    if ($r.StatusCode -eq 403) {
        Write-Host "  SKIP $domName — Forbidden (old Atlas domain, delete from portal)" -ForegroundColor DarkYellow
        return $false
    }
    if ($r.StatusCode -ne 200) {
        Write-Host "  UNPUBLISH $domName — FAIL ($($r.StatusCode) $($r.Content))" -ForegroundColor Red
        return $false
    }
    # Step 2: DELETE
    $r2 = Invoke-WebRequest "$base/datagovernance/catalog/businessdomains/${domId}?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
    if ($r2.StatusCode -in 200,204) {
        Write-Host "  DEL $domName — OK" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  DEL $domName — FAIL ($($r2.StatusCode) $($r2.Content))" -ForegroundColor Red
        return $false
    }
}

# ======================================================================
#  PHASE 1 — UNPUBLISH + DELETE ALL TERMS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 1 — UNPUBLISH + DELETE ALL TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$doms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
Write-Host "Domains found: $($doms.Count)"

$termOk = 0; $termFail = 0; $termSkip = 0
foreach ($d in $doms) {
    try {
        $terms = (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=200" -Headers $headers -ErrorAction Stop).value
    } catch {
        # 403 on listing terms for old Atlas domains
        continue
    }
    if (-not $terms -or $terms.Count -eq 0) { continue }
    Write-Host "  Domain '$($d.name)' — $($terms.Count) terms"
    foreach ($t in $terms) {
        if ($t.status -eq "Draft") {
            # Already Draft — just delete
            $r = Invoke-WebRequest "$base/datagovernance/catalog/terms/$($t.id)?$api" -Headers $headers -Method DELETE -SkipHttpErrorCheck
            if ($r.StatusCode -in 200,204) {
                $termOk++; Write-Host "    DEL $($t.name) (was Draft) — OK" -ForegroundColor Green
            } else {
                $termFail++; Write-Host "    DEL $($t.name) — FAIL ($($r.StatusCode))" -ForegroundColor Red
            }
        } else {
            $ok = Remove-Term $t.id $t.name $d.id
            if ($ok) { $termOk++ } else { $termFail++ }
        }
    }
}
Write-Host "`nTerms: $termOk deleted / $termFail failed" -ForegroundColor $(if($termFail -eq 0){"Green"}else{"Yellow"})

# ======================================================================
#  PHASE 2 — UNPUBLISH + DELETE ALL DOMAINS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 2 — UNPUBLISH + DELETE DOMAINS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Refresh domain list after term deletions
$doms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
# Delete children first (domains with parentId), then parents
$children = @($doms | Where-Object { $_.parentId })
$parents  = @($doms | Where-Object { -not $_.parentId })

$domOk = 0; $domFail = 0; $domSkip = 0
foreach ($d in ($children + $parents)) {
    $ok = Remove-Domain $d.id $d.name
    if ($ok) { $domOk++ } else { $domFail++ }
}
Write-Host "`nDomains: $domOk deleted / $domFail failed (old Atlas domains need portal deletion)" -ForegroundColor $(if($domFail -eq 0){"Green"}else{"Yellow"})

# Verify
$remaining = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
Write-Host "Remaining: $($remaining.Count) domains"
if ($remaining.Count -gt 0) {
    $remaining | ForEach-Object { Write-Host "  STILL: $($_.name) [$($_.type)]" -ForegroundColor DarkYellow }
}

# ======================================================================
#  PHASE 3 — CREATE DOMAIN HIERARCHY
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 3 — CREATE DOMAIN HIERARCHY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$users = Get-Content "$PSScriptRoot\demo_users.json" | ConvertFrom-Json

function New-Domain($name, $desc, $type, $color, $parentId) {
    $id = [guid]::NewGuid().ToString()
    $body = @{
        id = $id; name = $name; description = $desc
        status = "Published"; type = $type; isRestricted = $false
        thumbnail = @{ color = $color }
        contacts = @{ owner = @(@{ id = $myOid; description = "Admin" }) }
        domains = @(); managedAttributes = @()
    }
    if ($parentId) { $body["parentId"] = $parentId }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
        Write-Host "  + $name [$type] — OK (id=$($r.id))" -ForegroundColor Green
        return $r.id
    } catch {
        Write-Host "  + $name [$type] — FAIL ($($_.Exception.Response.StatusCode))" -ForegroundColor Red
        return $null
    }
}

# L1: Root
$rootId = New-Domain "TTE Group" "Root governance domain for TTE industrial group." "FunctionalUnit" "#1B2631" $null

# L2: Lines of Business
$finLobId  = New-Domain "Finance and ESG"             "Financial reporting, ESG metrics, CSRD compliance, treasury and accounting." "LineOfBusiness" "#2E86C1" $rootId
$custLobId = New-Domain "Customer and Sales"          "Customer 360, CRM, sales pipeline, B2B/B2C segmentation."                  "LineOfBusiness" "#27AE60" $rootId
$hrLobId   = New-Domain "HR and People"               "Workforce analytics, talent management, payroll, engagement."              "LineOfBusiness" "#8E44AD" $rootId
$opsLobId  = New-Domain "Operations and Industrial"   "Operational performance, industrial assets, supply chain, maintenance."    "LineOfBusiness" "#E67E22" $rootId
$techLobId = New-Domain "Technology and Data Platform" "Data platform health, data quality, infrastructure, BI & analytics."      "LineOfBusiness" "#2C3E50" $rootId

# L3: Data Domains (sub-domains)
$finAcct   = New-Domain "Accounting and Reporting"   "General ledger, P&L, balance sheet, statutory and management reporting."       "DataDomain" "#3498DB" $finLobId
$finTreas  = New-Domain "Treasury and Risk"          "Cash management, FX exposure, financial risk, credit and liquidity."            "DataDomain" "#5DADE2" $finLobId
$finEsg    = New-Domain "ESG and Sustainability"     "Carbon footprint, CSRD compliance, ESG scores, environmental KPIs."            "DataDomain" "#1ABC9C" $finLobId
$custCrm   = New-Domain "CRM and Customer Data"     "Customer master, contact management, segmentation, consent and preferences."   "DataDomain" "#2ECC71" $custLobId
$custComm  = New-Domain "Commercial Analytics"       "Sales pipeline, forecasting, pricing, market share, channel performance."      "DataDomain" "#58D68D" $custLobId
$hrTalent  = New-Domain "Talent Management"          "Recruitment, onboarding, career development, succession planning."             "DataDomain" "#9B59B6" $hrLobId
$hrWork    = New-Domain "Workforce Analytics"        "Headcount, turnover, absenteeism, compensation benchmarking."                  "DataDomain" "#AF7AC5" $hrLobId
$opsAsset  = New-Domain "Industrial Assets"          "Equipment registry, maintenance, inspections, corrosion, predictive analytics." "DataDomain" "#E74C3C" $opsLobId
$opsSC     = New-Domain "Supply Chain and Logistics" "Procurement, inventory, warehousing, transport, supplier performance."         "DataDomain" "#F39C12" $opsLobId
$techDE    = New-Domain "Data Engineering"           "Pipelines, data quality, lineage, schema management, ingestion."               "DataDomain" "#34495E" $techLobId
$techBI    = New-Domain "BI and Analytics"            "Reports, dashboards, usage analytics, self-service BI governance."             "DataDomain" "#566573" $techLobId

# ======================================================================
#  PHASE 4 — CREATE GLOSSARY TERMS
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 4 — CREATE GLOSSARY TERMS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

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
        status = "Published"; domain = $domainId
        contacts = @{
            owner  = @( @{ id = $c.owner;    description = "Data Owner" } )
            expert = @( @{ id = $c.steward;  description = "Data Steward" },
                        @{ id = $users.'cdo'; description = "Chief Data Officer" } )
        }
    }
    if ($acronyms) { $body["acronyms"] = $acronyms }
    $json = $body | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod "$base/datagovernance/catalog/terms?$api" -Headers $headers -Method Post -Body $json -ErrorAction Stop
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
New-Term "Carbon Footprint"     "Total greenhouse gas emissions caused directly or indirectly."                            $finEsg $null
New-Term "ESG Score"            "Composite rating measuring Environmental, Social, and Governance performance."            $finEsg @("ESG")
New-Term "CSRD Compliance"      "Adherence to Corporate Sustainability Reporting Directive requirements."                  $finEsg @("CSRD")
New-Term "Scope 1 Emissions"    "Direct GHG emissions from owned or controlled sources."                                  $finEsg $null
New-Term "Scope 2 Emissions"    "Indirect GHG emissions from purchased electricity, steam, heating, and cooling."         $finEsg $null
New-Term "Water Intensity"      "Volume of water consumed per unit of production or revenue."                              $finEsg $null

# ── CRM and Customer Data ──
Write-Host "  Sub-domain: CRM and Customer Data" -ForegroundColor Yellow
New-Term "Customer ID"          "Unique identifier assigned to each customer across all systems."                           $custCrm $null
New-Term "Customer Lifetime Value" "Predicted net profit from the entire future relationship with a customer."             $custCrm @("CLV")
New-Term "Net Promoter Score"   "Customer loyalty metric based on likelihood to recommend."                                $custCrm @("NPS")
New-Term "Churn Rate"           "Percentage of customers who stop using the product or service in a given period."         $custCrm $null
New-Term "Customer Segment"     "Classification of customers into groups based on shared characteristics."                 $custCrm $null
New-Term "GDPR Consent Status"  "Record of customer consent for data processing under GDPR."                              $custCrm $null

# ── Commercial Analytics ──
Write-Host "  Sub-domain: Commercial Analytics" -ForegroundColor Yellow
New-Term "Sales Pipeline"       "Total value and stage distribution of active sales opportunities."                        $custComm $null
New-Term "Lead Conversion Rate" "Percentage of leads that convert to paying customers."                                    $custComm $null
New-Term "Average Order Value"  "Mean monetary value of customer orders over a given period."                              $custComm @("AOV")
New-Term "Win Rate"             "Percentage of sales opportunities that result in a closed deal."                          $custComm $null
New-Term "Market Share"         "Percentage of total market revenue captured by the company."                              $custComm $null

# ── Talent Management ──
Write-Host "  Sub-domain: Talent Management" -ForegroundColor Yellow
New-Term "Employee ID"          "Unique identifier assigned to each employee across HR systems."                           $hrTalent $null
New-Term "Time to Hire"         "Number of days from job posting to accepted offer."                                       $hrTalent @("TTH")
New-Term "Training Hours"       "Total hours of professional development per employee per year."                           $hrTalent $null
New-Term "Succession Readiness" "Percentage of critical roles with identified and prepared successors."                    $hrTalent $null
New-Term "Engagement Score"     "Composite metric from employee surveys measuring satisfaction and motivation."            $hrTalent $null

# ── Workforce Analytics ──
Write-Host "  Sub-domain: Workforce Analytics" -ForegroundColor Yellow
New-Term "Headcount"            "Total number of active employees at a given point in time."                               $hrWork $null
New-Term "Turnover Rate"        "Percentage of employees leaving the organization in a given period."                      $hrWork $null
New-Term "Absenteeism Rate"     "Percentage of scheduled work days lost to unplanned absences."                            $hrWork $null
New-Term "Compensation Band"    "Salary range associated with a job grade or level."                                       $hrWork $null
New-Term "Gender Pay Gap"       "Difference in average earnings between male and female employees."                        $hrWork $null

# ── Industrial Assets ──
Write-Host "  Sub-domain: Industrial Assets" -ForegroundColor Yellow
New-Term "Equipment ID"         "Unique identifier for each physical asset in the industrial registry."                    $opsAsset $null
New-Term "OEE"                  "Overall Equipment Effectiveness — availability × performance × quality."                 $opsAsset @("OEE")
New-Term "MTBF"                 "Mean Time Between Failures — average operating time between breakdowns."                 $opsAsset @("MTBF")
New-Term "Downtime"             "Total time equipment is non-operational due to failure or maintenance."                   $opsAsset $null
New-Term "Corrosion Loop"       "Defined group of equipment sharing similar corrosion degradation mechanisms."             $opsAsset $null
New-Term "Safety Incident"      "Any event resulting in injury, illness, or near-miss in the workplace."                  $opsAsset $null
New-Term "Production Yield"     "Ratio of usable output to total input in a manufacturing process."                       $opsAsset $null

# ── Supply Chain and Logistics ──
Write-Host "  Sub-domain: Supply Chain and Logistics" -ForegroundColor Yellow
New-Term "Lead Time"            "Time elapsed from order placement to delivery."                                           $opsSC $null
New-Term "Inventory Turnover"   "Number of times inventory is sold and replaced in a given period."                       $opsSC $null
New-Term "On-Time Delivery"     "Percentage of orders delivered by the promised date."                                     $opsSC @("OTD")
New-Term "Supplier Score"       "Composite rating of supplier quality, reliability, and cost-effectiveness."              $opsSC $null
New-Term "Procurement Spend"    "Total expenditure on goods and services from external suppliers."                         $opsSC $null

# ── Data Engineering ──
Write-Host "  Sub-domain: Data Engineering" -ForegroundColor Yellow
New-Term "Data Quality Score"   "Composite metric measuring accuracy, completeness, timeliness, and consistency of data." $techDE @("DQS")
New-Term "Data Freshness"       "Time since the most recent data update in a dataset."                                    $techDE $null
New-Term "Pipeline SLA"         "Service Level Agreement for data pipeline execution time and reliability."                $techDE @("SLA")
New-Term "Schema Drift"         "Unplanned changes to data structure detected between pipeline runs."                     $techDE $null
New-Term "Data Lineage"         "End-to-end trace of data origin, transformations, and consumption."                      $techDE $null

# ── BI and Analytics ──
Write-Host "  Sub-domain: BI and Analytics" -ForegroundColor Yellow
New-Term "Active Users"         "Number of unique users who accessed reports or dashboards in a given period."             $techBI @("DAU","MAU")
New-Term "Report Adoption Rate" "Percentage of target audience actively using a published report."                        $techBI $null
New-Term "Query Latency"        "Time taken for a query to return results from the analytics engine."                     $techBI $null
New-Term "Self-Service Ratio"   "Percentage of reports created by business users vs. central BI team."                    $techBI $null
New-Term "Refresh Failure Rate" "Percentage of scheduled data refreshes that fail in a given period."                     $techBI $null

# ======================================================================
#  PHASE 5 — VERIFICATION
# ======================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PHASE 5 — VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$allDoms = (Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?$api" -Headers $headers).value
$newDoms = $allDoms | Where-Object { $_.name -in @("TTE Group","Finance and ESG","Customer and Sales","HR and People","Operations and Industrial","Technology and Data Platform","Accounting and Reporting","Treasury and Risk","ESG and Sustainability","CRM and Customer Data","Commercial Analytics","Talent Management","Workforce Analytics","Industrial Assets","Supply Chain and Logistics","Data Engineering","BI and Analytics") }

Write-Host "`nNew Domain Hierarchy:" -ForegroundColor Green
$roots = $newDoms | Where-Object { -not $_.parentId }
foreach ($root in $roots) {
    Write-Host "  $($root.name) [$($root.type)]" -ForegroundColor White
    $lobs = $newDoms | Where-Object { $_.parentId -eq $root.id }
    foreach ($lob in $lobs) {
        Write-Host "    +-- $($lob.name) [$($lob.type)]" -ForegroundColor White
        $subs = $newDoms | Where-Object { $_.parentId -eq $lob.id }
        foreach ($sub in $subs) {
            $tc = 0
            try { $tc = (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($sub.id)&top=100" -Headers $headers).value.Count } catch {}
            Write-Host "        +-- $($sub.name) [$($sub.type)] ($tc terms)" -ForegroundColor White
        }
    }
}

# Count total terms across new domains
$totalTerms = 0
foreach ($d in $newDoms) {
    try { $totalTerms += (Invoke-RestMethod "$base/datagovernance/catalog/terms?$api&domainId=$($d.id)&top=100" -Headers $headers).value.Count } catch {}
}

Write-Host "`nOld Atlas domains still present (delete from portal):" -ForegroundColor DarkYellow
$oldDoms = $allDoms | Where-Object { $_.name -notin @("TTE Group","Finance and ESG","Customer and Sales","HR and People","Operations and Industrial","Technology and Data Platform","Accounting and Reporting","Treasury and Risk","ESG and Sustainability","CRM and Customer Data","Commercial Analytics","Talent Management","Workforce Analytics","Industrial Assets","Supply Chain and Logistics","Data Engineering","BI and Analytics") }
$oldDoms | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor DarkYellow }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  New domains : $($newDoms.Count) (1 root + 5 LoB + 11 DataDomain)"
Write-Host "  New terms   : $totalTerms glossary terms with owner/steward/CDO"
Write-Host "  Old domains : $($oldDoms.Count) (locked — require portal deletion)"
Write-Host "========================================"
