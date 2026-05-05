# Enrich UC data products: businessUse, termsOfUse, documentation, endorsed
$ErrorActionPreference = "Continue"
if (-not $token) { $token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv) }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com"
$api = "?api-version=2026-03-20-preview"

# Per-DP rich content
$content = @{
  "Executive Financial Dashboards" = @{
    businessUse = "Authoritative source for monthly close, board reporting, and CFO scorecards. Combines GL, AP/AR, treasury, and management accounting. Used by the CFO office, FP&A, controllership, and business unit finance leads to make capital allocation, budget, and forecasting decisions."
    termsOfUse = @(
      @{ name = "Financial Data Acceptable Use Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/FinanceAUP.aspx" },
      @{ name = "SOX Restricted Data Handling"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/SOX-Handling.aspx" }
    )
    documentation = @(
      @{ name = "Data Dictionary"; url = "https://contoso.sharepoint.com/sites/finance-bi/Pages/DataDictionary.aspx" },
      @{ name = "Monthly Close Runbook"; url = "https://contoso.sharepoint.com/sites/finance-bi/Pages/CloseRunbook.aspx" },
      @{ name = "Reconciliation Guide"; url = "https://contoso.sharepoint.com/sites/finance-bi/Pages/Recon.aspx" }
    )
  }
  "ESG and CSRD Reporting Pack" = @{
    businessUse = "Curated dataset for ESG and CSRD regulatory reporting. Covers Scope 1/2/3 emissions, water and waste KPIs, social and governance metrics. Used by Sustainability, Investor Relations, and external auditors."
    termsOfUse = @(
      @{ name = "ESG Data Disclosure Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/ESG-Disclosure.aspx" }
    )
    documentation = @(
      @{ name = "CSRD Mapping Workbook"; url = "https://contoso.sharepoint.com/sites/sustainability/Pages/CSRD-Mapping.aspx" },
      @{ name = "Emissions Methodology"; url = "https://contoso.sharepoint.com/sites/sustainability/Pages/EmissionsMethodology.aspx" }
    )
  }
  "Customer 360" = @{
    businessUse = "Single source of truth for customer identity. Enables personalised marketing, churn prediction, lifetime value modelling, and cross-channel orchestration. Used by Marketing, Sales, CX, and Finance for customer lifecycle reporting and revenue attribution."
    termsOfUse = @(
      @{ name = "Customer Data Acceptable Use Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/CustomerDataAUP.aspx" },
      @{ name = "GDPR Personal Data Handling"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/GDPR-PII.aspx" }
    )
    documentation = @(
      @{ name = "Customer 360 Data Dictionary"; url = "https://contoso.sharepoint.com/sites/customer360/Pages/DataDictionary.aspx" },
      @{ name = "Customer Master Stewardship Guide"; url = "https://contoso.sharepoint.com/sites/customer360/Pages/Stewardship.aspx" },
      @{ name = "Onboarding Runbook"; url = "https://contoso.sharepoint.com/sites/customer360/Pages/Onboarding.aspx" }
    )
  }
  "Workforce Analytics Dashboard" = @{
    businessUse = "People-analytics product covering headcount, attrition, engagement, compensation bands, and diversity. Used by HR business partners, executive committee, and managers to make workforce planning, retention, and DEI decisions."
    termsOfUse = @(
      @{ name = "HR Data Confidentiality Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/HR-Confidentiality.aspx" },
      @{ name = "Pay & Comp Data Restricted Use"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/Pay-Restricted.aspx" }
    )
    documentation = @(
      @{ name = "Workforce Metrics Catalog"; url = "https://contoso.sharepoint.com/sites/people-analytics/Pages/Metrics.aspx" },
      @{ name = "Manager Self-Service Guide"; url = "https://contoso.sharepoint.com/sites/people-analytics/Pages/MgrGuide.aspx" }
    )
  }
  "Operational Performance Hub" = @{
    businessUse = "Real-time operational dataset for plant performance, equipment health, maintenance backlog, supply chain throughput, and safety metrics. Used by plant managers, maintenance planners, and corporate operations to maximise OEE, reduce downtime, and drive safety to TRIR=0."
    termsOfUse = @(
      @{ name = "Operations Data Use Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/Ops-AUP.aspx" }
    )
    documentation = @(
      @{ name = "Site KPI Definitions"; url = "https://contoso.sharepoint.com/sites/operations/Pages/KPIs.aspx" },
      @{ name = "Maintenance Workflow Reference"; url = "https://contoso.sharepoint.com/sites/operations/Pages/Maintenance.aspx" },
      @{ name = "Safety Reporting Standard"; url = "https://contoso.sharepoint.com/sites/operations/Pages/Safety.aspx" }
    )
  }
  "Data Platform Health Monitor" = @{
    businessUse = "Cross-platform observability product. Tracks data product certifications, asset classification coverage, lineage completeness, freshness SLAs, scan health, and access reviews. Used by the central data office, CDO, and platform engineers to govern the estate."
    termsOfUse = @(
      @{ name = "Platform Telemetry Use Policy"; url = "https://contoso.sharepoint.com/sites/governance/SitePages/Platform-Telemetry.aspx" }
    )
    documentation = @(
      @{ name = "Health Metric Definitions"; url = "https://contoso.sharepoint.com/sites/data-platform/Pages/HealthMetrics.aspx" },
      @{ name = "Certification Process"; url = "https://contoso.sharepoint.com/sites/data-platform/Pages/Certification.aspx" },
      @{ name = "Incident Response Runbook"; url = "https://contoso.sharepoint.com/sites/data-platform/Pages/Incidents.aspx" }
    )
  }
}

$dps = (Invoke-RestMethod "$base/datagovernance/catalog/dataproducts$api" -Headers $headers).value | Where-Object { $content.ContainsKey($_.name) }

$ok = 0
foreach ($dp in $dps) {
  $c = $content[$dp.name]
  $body = @{
    id           = $dp.id
    name         = $dp.name
    type         = $dp.type
    status       = "Published"
    domain       = $dp.domain
    description  = $dp.description
    contacts     = $dp.contacts
    businessUse  = $c.businessUse
    termsOfUse   = $c.termsOfUse
    documentation = $c.documentation
    endorsed     = $true
  } | ConvertTo-Json -Depth 10
  $r = Invoke-WebRequest "$base/datagovernance/catalog/dataproducts/$($dp.id)$api" -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -eq 200) {
    $ok++
    Write-Host "  + $($dp.name)" -ForegroundColor Green
  } else {
    $msg = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    Write-Host "  ! $($dp.name) -> $($r.StatusCode): $($msg.Substring(0,[Math]::Min(300,$msg.Length)))" -ForegroundColor Yellow
  }
}
Write-Host "`nEnriched: $ok / $($dps.Count)" -ForegroundColor Cyan

# Verify
Write-Host "`n--- Verification (Customer 360) ---"
$v = Invoke-RestMethod "$base/datagovernance/catalog/dataproducts/dd58e805-6ac3-4566-b785-03fec789610c$api" -Headers $headers
$v | ConvertTo-Json -Depth 10
