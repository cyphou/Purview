# Sprint 3 — Expand Business Glossary from 33 to 100+ terms
# Creates new glossary terms in Global, Finance, Customer, HR, and a new Operations glossary

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Glossary GUIDs
$glossaries = @{
    Global   = "32dc6bee-8833-4d03-8272-756515a19599"
    HR       = "de1f8830-80ac-47e4-bc0c-839c8eef351e"
    Finance  = "cd9471d5-13d3-45a8-9305-8b415e5b0618"
    Customer = "dbbb44b9-8f48-43f6-a44a-47aec06bed9b"
    TTE      = "75c6f40b-ee98-47c6-ba9a-3ea9ab9e6fae"
}

# First, create Operations glossary (doesn't exist yet)
Write-Host "=== Creating Operations Glossary ===" -ForegroundColor Cyan
$opsGlossaryPayload = @{
    name = "Operations"
    shortDescription = "Glossary for industrial operations, maintenance, supply chain, and plant management terminology"
    longDescription = "Covers all operational and industrial terms used across refinery sites, SAP systems, equipment management, and supply chain processes"
} | ConvertTo-Json -Depth 5

try {
    $opsResult = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $opsGlossaryPayload
    $glossaries["Operations"] = $opsResult.guid
    Write-Host "  Created Operations glossary (GUID: $($opsResult.guid))" -ForegroundColor Green
} catch {
    Write-Host "  Failed to create Operations glossary: $($_.Exception.Message)" -ForegroundColor Red
}

# Define all new terms by glossary
$allTerms = @{
    Global = @(
        @{ name = "Revenue"; short = "Total income generated from business operations before any expenses are deducted"; long = "The top-line figure representing all income from sales of goods and services. Used across Finance, Customer, and Operations domains." },
        @{ name = "Customer"; short = "An individual or organization that purchases goods or services"; long = "Core business entity tracked across CRM, Salesforce, and transactional systems. Foundation for Customer 360 data product." },
        @{ name = "Employee"; short = "An individual employed by the organization in any capacity"; long = "Tracked across HR systems, payroll, and workforce analytics. Subject to strict PII governance." },
        @{ name = "Asset"; short = "A physical or digital resource owned or controlled by the organization"; long = "Includes industrial equipment, data assets, financial instruments, and digital resources." },
        @{ name = "Contract"; short = "A legally binding agreement between two or more parties"; long = "Covers customer contracts, vendor agreements, employment contracts, and service level agreements." },
        @{ name = "Data Quality Score"; short = "A composite metric measuring the reliability and accuracy of a dataset"; long = "Calculated from completeness, freshness, uniqueness, validity, and consistency dimensions. Published on each data product." },
        @{ name = "SLA"; short = "Service Level Agreement — a commitment to deliver data or services within defined parameters"; long = "Applied to data products, pipeline refresh targets, and data delivery commitments." },
        @{ name = "KPI"; short = "Key Performance Indicator — a measurable value demonstrating progress toward a business objective"; long = "Used across all domains to track operational, financial, and strategic performance." },
        @{ name = "Business Unit"; short = "A distinct division or segment within the organization with its own operations and objectives"; long = "Examples: RC Division, Company B, LIFT Tenant. Mapped to Purview collections and governance domains." },
        @{ name = "Region"; short = "A geographic area used to organize operations, reporting, and compliance requirements"; long = "Key regions: France, Belgium, Germany, UK, US. Used for site-level data partitioning (PI-DA-RC-XX-YYY pattern)." },
        @{ name = "Country"; short = "The nation in which a business operation, site, or customer is located"; long = "Used for regulatory compliance (GDPR, CSRD), tax reporting, and operational segmentation." },
        @{ name = "Currency"; short = "The monetary unit used for financial transactions and reporting"; long = "Primary currencies: EUR, GBP, USD. Critical for financial consolidation and cross-border reporting." },
        @{ name = "Fiscal Year"; short = "The 12-month period used for financial reporting and budgeting"; long = "May differ from calendar year. All financial KPIs and budgets are aligned to fiscal year boundaries." },
        @{ name = "Budget"; short = "The planned financial allocation for a specific period, department, or project"; long = "Compared against actuals in Finance BI dashboards. Key input for profitability and variance analysis." },
        @{ name = "Forecast"; short = "A projected estimate of future financial or operational performance"; long = "Generated monthly or quarterly. Used in Plan-to-Report business process for executive decision support." },
        @{ name = "Data Steward"; short = "A person accountable for the quality, governance, and lifecycle of data within a domain"; long = "Each governance domain has a named steward responsible for glossary terms, DQ rules, and access decisions." },
        @{ name = "Data Product"; short = "A curated, documented, and governed dataset packaged for consumption by business users"; long = "Published in the Purview catalog with SLA, quality scores, and access request process. Foundation of the data marketplace." },
        @{ name = "Governance Domain"; short = "A business-aligned organizational boundary for data governance accountability"; long = "Five domains defined: Finance and ESG, Customer and Sales, HR and People, Operations and Industrial, Technology and Data Platform." },
        @{ name = "Lineage"; short = "The end-to-end path of data from source through transformation to consumption"; long = "Tracked via Process entities in Purview. Covers Snowflake queries, ADF pipelines, Fabric notebooks, and Power BI datasets." },
        @{ name = "Classification"; short = "A label identifying the sensitivity or category of data within an asset"; long = "Includes Microsoft built-in classifications (PII, financial) and custom classifications (French Phone, Complaints Type)." }
    )
    Finance = @(
        @{ name = "EBITDA"; short = "Earnings Before Interest, Taxes, Depreciation, and Amortization"; long = "A key profitability metric used in financial dashboards. Calculated from P&L data." },
        @{ name = "Cash Flow"; short = "The net movement of cash into and out of the organization over a period"; long = "Reported as Operating, Investing, and Financing cash flows. Critical for liquidity assessment." },
        @{ name = "Working Capital"; short = "Current assets minus current liabilities — measures short-term financial health"; long = "Monitored monthly in Finance BI. Alert triggered if ratio drops below threshold." },
        @{ name = "Cost of Goods Sold"; short = "Direct costs attributable to the production of goods sold by the organization"; long = "Key input for gross margin calculation. Sourced from SAP and ERP systems." },
        @{ name = "Operating Expenses"; short = "Day-to-day costs of running the business excluding direct production costs"; long = "Includes salaries, rent, utilities, and administrative costs. Tracked per business unit." },
        @{ name = "ESG Score"; short = "Environmental, Social, and Governance composite rating measuring sustainability performance"; long = "Aggregated from Scope 1/2/3 emissions, social metrics, and governance indicators. Required for CSRD reporting." },
        @{ name = "Carbon Footprint"; short = "Total greenhouse gas emissions caused directly or indirectly by the organization"; long = "Measured in CO2 equivalents. Broken down by Scope 1 (direct), Scope 2 (energy), Scope 3 (value chain)." },
        @{ name = "CSRD Metric"; short = "A data point required under the Corporate Sustainability Reporting Directive"; long = "EU regulation requiring standardized sustainability disclosures. Drives ESG data product requirements." },
        @{ name = "Scope 1 Emissions"; short = "Direct greenhouse gas emissions from sources owned or controlled by the organization"; long = "Includes refinery operations, company vehicles, and on-site fuel combustion." },
        @{ name = "Scope 2 Emissions"; short = "Indirect emissions from purchased electricity, heat, or steam"; long = "Calculated from energy consumption data across all sites." },
        @{ name = "Scope 3 Emissions"; short = "All other indirect emissions in the organization's value chain"; long = "Includes supply chain, logistics, employee commuting, and product end-of-life." },
        @{ name = "Audit Trail"; short = "A chronological record of all changes to financial data for compliance purposes"; long = "Required for SOX compliance and financial audits. Captured via Purview governance policies." },
        @{ name = "Variance Analysis"; short = "The comparison of actual results versus budgeted or forecasted figures"; long = "Key component of monthly financial reviews. Presented in CFO dashboards." },
        @{ name = "Net Revenue"; short = "Revenue after deducting returns, allowances, and discounts"; long = "The true top-line figure used for profitability calculations and executive reporting." },
        @{ name = "Capital Expenditure"; short = "Funds used to acquire, upgrade, or maintain physical assets"; long = "Tracked separately from operating expenses. Key metric for industrial site investments." },
        @{ name = "Depreciation"; short = "The systematic reduction in recorded value of a tangible asset over its useful life"; long = "Applied to refinery equipment, buildings, and industrial machinery. Impacts EBITDA bridge." }
    )
    Customer = @(
        @{ name = "NPS"; short = "Net Promoter Score — measures customer loyalty by asking likelihood to recommend"; long = "Scored -100 to +100. Tracked quarterly in Customer glossary. Key CX KPI." },
        @{ name = "Churn Rate"; short = "Percentage of customers who stop using a product or service in a given period"; long = "Calculated monthly. High churn triggers alerts in Customer 360 data product." },
        @{ name = "ARPU"; short = "Average Revenue Per User — total revenue divided by number of active customers"; long = "Segmented by product line, region, and customer tier." },
        @{ name = "CLV"; short = "Customer Lifetime Value — predicted total revenue from a customer over the entire relationship"; long = "Used for acquisition cost decisions and customer segmentation." },
        @{ name = "Customer Segment"; short = "A grouping of customers based on shared characteristics or behaviors"; long = "Segments defined by value tier (Gold/Silver/Bronze), industry, or geography." },
        @{ name = "Lead"; short = "A potential customer who has shown interest but has not yet made a purchase"; long = "Tracked in CRM/Salesforce. Converted to Opportunity when qualified." },
        @{ name = "Opportunity"; short = "A qualified sales prospect with an estimated value and close date"; long = "Managed in Salesforce pipeline. Feeds sales forecasting models." },
        @{ name = "Win Rate"; short = "Percentage of opportunities that result in a closed deal"; long = "Tracked by sales team, product line, and region. Key sales performance metric." },
        @{ name = "Sales Pipeline"; short = "The total value of all active opportunities at various stages of the sales process"; long = "Reported weekly in CRM dashboards. Feeds revenue forecasting." },
        @{ name = "Customer Onboarding"; short = "The process of integrating a new customer into the organization's systems and services"; long = "Measured by time-to-value and completion rate. Part of Customer Journey Map." },
        @{ name = "Support Ticket"; short = "A record of a customer service request, issue, or complaint"; long = "Tracked in service management system. Resolution time is a key SLA metric." },
        @{ name = "Resolution Time"; short = "The elapsed time from when a support ticket is opened to when it is resolved"; long = "Measured in hours. SLA target varies by priority (P1: 4h, P2: 24h, P3: 72h)." },
        @{ name = "CSAT"; short = "Customer Satisfaction Score — a direct measure of customer happiness with a product or service"; long = "Collected via post-interaction surveys. Scored 1-5 or 1-10." }
    )
    HR = @(
        @{ name = "Headcount"; short = "Total number of employees in the organization at a given point in time"; long = "Reported by department, region, and employment type (FTE, contract, intern)." },
        @{ name = "Attrition Rate"; short = "Percentage of employees who leave the organization over a period"; long = "Calculated monthly. Broken down by voluntary/involuntary, department, and tenure band." },
        @{ name = "Time to Hire"; short = "The number of days from job posting to accepted offer"; long = "Key recruitment efficiency metric. Target varies by role seniority." },
        @{ name = "Cost per Hire"; short = "Total recruitment cost divided by number of hires in the period"; long = "Includes agency fees, advertising, interviewer time, and onboarding costs." },
        @{ name = "Employee Engagement"; short = "A measure of employee commitment, motivation, and connection to the organization"; long = "Measured via annual or pulse surveys. Scores benchmarked against industry." },
        @{ name = "Training Hours"; short = "Total hours of professional development completed per employee"; long = "Tracked per employee, department, and training category. Compliance training tracked separately." },
        @{ name = "Diversity Index"; short = "A composite metric measuring workforce diversity across multiple dimensions"; long = "Includes gender, ethnicity, age, disability, and geographic representation." },
        @{ name = "Absenteeism Rate"; short = "Percentage of scheduled work days lost to unplanned absences"; long = "Excludes planned leave. High rates trigger manager alerts and well-being reviews." },
        @{ name = "Internal Mobility"; short = "Percentage of open positions filled by existing employees"; long = "Measures career development effectiveness. Target: 30%+ of fills from internal candidates." },
        @{ name = "Succession Plan"; short = "A strategy identifying and developing future leaders for critical roles"; long = "Covers C-suite, plant managers, and key technical positions. Updated annually." },
        @{ name = "Performance Rating"; short = "An assessment of an employee's work output and competencies over a review period"; long = "Typically rated 1-5. Used for compensation decisions, promotions, and development planning." }
    )
    Operations = @(
        @{ name = "Work Order"; short = "A formal request to perform maintenance, repair, or operational work on equipment or systems"; long = "Created in SAP. Linked to equipment, cost center, and maintenance plan. Key operational tracking entity." },
        @{ name = "Equipment"; short = "A physical asset such as machinery, pump, compressor, or vessel used in operations"; long = "Tracked by serial number, location, and maintenance history. Core entity in equipment register." },
        @{ name = "Downtime"; short = "The period during which equipment or a system is unavailable for production"; long = "Classified as planned (maintenance) or unplanned (failure). Directly impacts OEE." },
        @{ name = "OEE"; short = "Overall Equipment Effectiveness — a composite metric of Availability x Performance x Quality"; long = "Industry benchmark: 85%+. Calculated per equipment, line, and site. Primary operational KPI." },
        @{ name = "MTBF"; short = "Mean Time Between Failures — average operating time between equipment breakdowns"; long = "Higher is better. Used for reliability engineering and maintenance scheduling." },
        @{ name = "MTTR"; short = "Mean Time To Repair — average time required to restore equipment to operational status"; long = "Lower is better. Drives spare parts strategy and maintenance crew sizing." },
        @{ name = "Preventive Maintenance"; short = "Scheduled maintenance performed at regular intervals to prevent equipment failure"; long = "Planned via SAP Maintenance Plans. Reduces unplanned downtime." },
        @{ name = "Corrective Maintenance"; short = "Unscheduled maintenance performed to restore equipment after a failure"; long = "Triggered by breakdown events. Higher cost than preventive. Tracked via RAMSES." },
        @{ name = "Inspection"; short = "A systematic examination of equipment or processes to verify compliance and condition"; long = "Includes regulatory inspections, safety audits, and condition-based assessments." },
        @{ name = "Safety Incident"; short = "An unplanned event resulting in or having the potential for injury, damage, or environmental impact"; long = "Tracked in RAMSES. Classified by severity (near-miss, first aid, lost time, fatality). Zero-incident target." },
        @{ name = "Supply Chain Lead Time"; short = "The total time from order placement to delivery of goods or materials"; long = "Measured for raw materials, spare parts, and finished products. Key logistics metric." },
        @{ name = "Inventory Turn"; short = "The number of times inventory is sold and replaced over a period"; long = "Higher is generally better. Balanced against stockout risk for critical spare parts." },
        @{ name = "Production Batch"; short = "A specific quantity of product manufactured in a single production run"; long = "Tracked for quality control, traceability, and yield analysis." },
        @{ name = "Quality Control"; short = "The process of ensuring products and processes meet defined standards"; long = "Includes sampling, testing, statistical process control. Non-conformances trigger corrective actions." },
        @{ name = "Throughput"; short = "The volume of product processed through a system in a given time period"; long = "Measured in barrels/day for refineries, tonnes/hour for chemicals. Key capacity metric." },
        @{ name = "Turnaround"; short = "A planned major maintenance event requiring full or partial shutdown of a production unit"; long = "Typically every 4-6 years. Longest downtime event. Requires months of planning." },
        @{ name = "Process Safety"; short = "The discipline of managing hazards associated with industrial processes and hazardous materials"; long = "Governed by regulations (Seveso, OSHA PSM). Includes MOC, HAZOP, and barrier management." },
        @{ name = "Yield"; short = "The percentage of input material successfully converted to desired output product"; long = "Key efficiency metric for refining and chemical processes. Target varies by unit." },
        @{ name = "Energy Consumption"; short = "The total amount of energy used by a site, unit, or process"; long = "Measured in MWh or GJ. Feeds Scope 2 emissions calculations and energy efficiency KPIs." },
        @{ name = "Flaring"; short = "The controlled burning of excess gas during industrial operations"; long = "Environmental impact metric. Subject to regulatory limits. Reduction is a key ESG target." }
    )
}

$totalCreated = 0
$totalFailed = 0

foreach ($glossaryName in $allTerms.Keys) {
    $glossaryGuid = $glossaries[$glossaryName]
    if (-not $glossaryGuid) {
        Write-Host "Skipping $glossaryName — no GUID" -ForegroundColor Yellow
        continue
    }
    
    $terms = $allTerms[$glossaryName]
    Write-Host ""
    Write-Host "=== $glossaryName Glossary ($($terms.Count) new terms) ===" -ForegroundColor Cyan
    
    foreach ($t in $terms) {
        Write-Host "  Creating: $($t.name)..." -NoNewline
        
        $termPayload = @{
            name = $t.name
            shortDescription = $t.short
            longDescription = $t.long
            anchor = @{
                glossaryGuid = $glossaryGuid
            }
            status = "Approved"
        } | ConvertTo-Json -Depth 5
        
        try {
            $result = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/glossary/term?api-version=2022-03-01-preview" -Headers $headers -Method Post -Body $termPayload
            Write-Host " OK" -ForegroundColor Green
            $totalCreated++
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg -match "409" -or $errMsg -match "already exists") {
                Write-Host " SKIP (exists)" -ForegroundColor Yellow
            } else {
                Write-Host " FAILED: $errMsg" -ForegroundColor Red
                $totalFailed++
            }
        }
    }
}

Write-Host ""
Write-Host "=== Sprint 3 Complete ===" -ForegroundColor Cyan
Write-Host "  Terms created: $totalCreated | Failed: $totalFailed"
Write-Host "  Total terms (existing 33 + new): $($totalCreated + 33)"
