# Add OKRs (Objectives + Key Results), CDEs, and Custom Attributes to our 5 LoBs
$ErrorActionPreference = "Continue"
if (-not $token) { $token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv) }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com"
$api = "?api-version=2026-03-20-preview"

# LoB GUIDs
$LoB = @{
  "Finance"     = "da176475-282f-4f22-9a06-7661d0e25916"
  "Customer"    = "f1b1d5fe-3617-4786-9894-ffd8662bead7"
  "HR"          = "f64840cf-bac7-4d21-b43f-b02b3e9f5ba6"
  "Operations"  = "84f0ee4c-375b-4714-bd0d-a2d9dade9f36"
  "Technology"  = "7f5695d1-8e2e-44f1-9c08-5c1e2455cee7"
}

# Owner GUIDs (from demo_users.json)
$Owner = @{
  "Finance"    = "e8c4054b-55fd-4783-bc2f-a1ef32f8ea7b"
  "Customer"   = "c51caf82-91a2-4ad1-a12e-86970c20f1f8"
  "HR"         = "e38ff89a-05f2-478b-b9da-5612656a19e9"
  "Operations" = "51ad0829-6d52-4b75-9bd4-c49aa3df3413"
  "Technology" = "77a408f9-0068-4659-bceb-58b93cb7b785"
}

function New-Owner($lob) { @{ owner = @(@{ id = $Owner[$lob] }) } }

# ======= OBJECTIVES (OKRs) =======
Write-Host "`n=== Creating OKR Objectives + Key Results ===" -ForegroundColor Cyan
$objectives = @(
  @{ lob="Finance"; def="Achieve top-quartile financial reporting accuracy and ESG transparency"; target="2026-12-31T23:59:59Z";
     krs = @(
       @{ definition="Reduce monthly close cycle to <5 business days"; goal=80; max=100 },
       @{ definition="Achieve 100% CSRD-aligned ESG metric coverage"; goal=100; max=100 },
       @{ definition="Cut financial data quality incidents by 50%"; goal=50; max=100 }
     )},
  @{ lob="Customer"; def="Deliver a unified, trusted Customer 360 view across all channels"; target="2026-09-30T23:59:59Z";
     krs = @(
       @{ definition="Onboard 100% of customer touchpoints into the Customer 360 product"; goal=100; max=100 },
       @{ definition="Increase NPS by 8 points"; goal=8; max=15 },
       @{ definition="Reduce customer support ticket resolution time by 30%"; goal=30; max=50 }
     )},
  @{ lob="HR"; def="Build a data-driven, equitable, high-performing workforce"; target="2026-12-31T23:59:59Z";
     krs = @(
       @{ definition="Reduce voluntary attrition rate to <8%"; goal=8; max=15 },
       @{ definition="Achieve 100% manager adoption of Workforce Analytics Dashboard"; goal=100; max=100 },
       @{ definition="Close gender pay-gap to <2% in all bands"; goal=2; max=10 }
     )},
  @{ lob="Operations"; def="Improve plant uptime, safety, and supply-chain visibility"; target="2026-12-31T23:59:59Z";
     krs = @(
       @{ definition="Increase Overall Equipment Effectiveness (OEE) to 85%"; goal=85; max=100 },
       @{ definition="Reduce unplanned downtime by 25%"; goal=25; max=50 },
       @{ definition="Achieve zero recordable safety incidents (TRIR=0)"; goal=0; max=5 }
     )},
  @{ lob="Technology"; def="Establish a trusted, governed, scalable enterprise data platform"; target="2026-12-31T23:59:59Z";
     krs = @(
       @{ definition="Reach 80% data product certification rate"; goal=80; max=100 },
       @{ definition="Achieve 95% of critical assets classified and labeled"; goal=95; max=100 },
       @{ definition="Reduce mean-time-to-discovery (MTTD) for new datasets to <2 days"; goal=2; max=10 }
     )}
)

$createdObjs = @{}
foreach ($o in $objectives) {
  $body = @{ definition = $o.def; domain = $LoB[$o.lob]; targetDate = $o.target; contacts = (New-Owner $o.lob); status = "Draft" } | ConvertTo-Json -Depth 6
  $r = Invoke-WebRequest "$base/datagovernance/catalog/objectives$api" -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -eq 201 -or $r.StatusCode -eq 200) {
    $obj = ($r.Content | ConvertFrom-Json)
    $createdObjs[$o.lob] = $obj.id
    Write-Host "  + Objective [$($o.lob)] $($o.def.Substring(0,[Math]::Min(60,$o.def.Length)))" -ForegroundColor Green

    # Publish
    $pubBody = @{ id=$obj.id; definition=$o.def; domain=$LoB[$o.lob]; targetDate=$o.target; contacts=(New-Owner $o.lob); status="Published" } | ConvertTo-Json -Depth 6
    $pr = Invoke-WebRequest "$base/datagovernance/catalog/objectives/$($obj.id)$api" -Headers $headers -Method PUT -Body $pubBody -SkipHttpErrorCheck
    Write-Host "    publish -> $($pr.StatusCode)" -ForegroundColor DarkGray

    # Create Key Results
    foreach ($k in $o.krs) {
      $krBody = @{ definition=$k.definition; domainId=$LoB[$o.lob]; progress=0.0; goal=$k.goal; max=$k.max; status="OnTrack" } | ConvertTo-Json -Depth 5
      $kr = Invoke-WebRequest "$base/datagovernance/catalog/objectives/$($obj.id)/keyResults$api" -Headers $headers -Method POST -Body $krBody -SkipHttpErrorCheck
      if ($kr.StatusCode -in 200,201) { Write-Host "    + KR: $($k.definition)" -ForegroundColor Cyan }
      else { $msg = if($kr.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($kr.Content)}else{$kr.Content}; Write-Host "    ! KR failed $($kr.StatusCode): $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" -ForegroundColor Yellow }
    }
  } else {
    $msg = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    Write-Host "  ! Objective [$($o.lob)] failed $($r.StatusCode): $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" -ForegroundColor Yellow
  }
}

# ======= CRITICAL DATA ELEMENTS =======
Write-Host "`n=== Creating Critical Data Elements ===" -ForegroundColor Cyan
$cdes = @(
  @{ lob="Finance";    name="GL Account Number";        type="Text";   desc="Unique general-ledger account identifier used in all financial postings." },
  @{ lob="Finance";    name="Fiscal Period";            type="Text";   desc="Year/month accounting period (YYYY-MM) for financial close and reporting." },
  @{ lob="Finance";    name="Reporting Currency";       type="Text";   desc="ISO 4217 currency code used as the reporting currency for consolidated statements." },
  @{ lob="Customer";   name="Customer Master ID";       type="Text";   desc="Golden customer identifier that stitches CRM, billing, and support records together." },
  @{ lob="Customer";   name="Email Address (PII)";      type="Text";   desc="Customer email — classified as personal data, GDPR scope." },
  @{ lob="Customer";   name="Customer Lifetime Value";  type="Number"; desc="Modeled CLV in reporting currency. Source-of-truth metric for marketing prioritization." },
  @{ lob="HR";         name="Employee ID";              type="Text";   desc="Workday-issued unique employee identifier. Mandatory join key for all people analytics." },
  @{ lob="HR";         name="Compensation Band";        type="Text";   desc="Salary band code. Confidential — restricted to HR and approved analysts." },
  @{ lob="HR";         name="Cost Center";              type="Text";   desc="Org-unit cost center charged for the employee. Drives finance allocations." },
  @{ lob="Operations"; name="Equipment ID";             type="Text";   desc="Functional location / equipment number from SAP PM." },
  @{ lob="Operations"; name="Work Order Number";        type="Text";   desc="SAP work order identifier for maintenance, inspection, and operations activities." },
  @{ lob="Operations"; name="Material Number";          type="Text";   desc="SAP material master number used in inventory and supply chain." },
  @{ lob="Technology"; name="Asset Sensitivity Label";  type="Text";   desc="MIP/Purview sensitivity label applied to the asset (Public/Internal/Confidential/Restricted)." },
  @{ lob="Technology"; name="Data Quality Score";       type="Number"; desc="0-100 composite score combining completeness, freshness, validity, and lineage coverage." },
  @{ lob="Technology"; name="Owner Email";              type="Text";   desc="Verified owner contact for governance and incident response." }
)

$createdCdes = 0
foreach ($c in $cdes) {
  $body = @{ name=$c.name; description=$c.desc; dataType=$c.type; domain=$LoB[$c.lob]; contacts=(New-Owner $c.lob); status="Draft" } | ConvertTo-Json -Depth 6
  $r = Invoke-WebRequest "$base/datagovernance/catalog/criticalDataElements$api" -Headers $headers -Method POST -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -in 200,201) {
    $cde = ($r.Content | ConvertFrom-Json)
    $createdCdes++
    Write-Host "  + CDE [$($c.lob)] $($c.name)" -ForegroundColor Green
    # Publish
    $pubBody = @{ id=$cde.id; name=$c.name; description=$c.desc; dataType=$c.type; domain=$LoB[$c.lob]; contacts=(New-Owner $c.lob); status="Published" } | ConvertTo-Json -Depth 6
    Invoke-WebRequest "$base/datagovernance/catalog/criticalDataElements/$($cde.id)$api" -Headers $headers -Method PUT -Body $pubBody -SkipHttpErrorCheck | Out-Null
  } else {
    $msg = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    Write-Host "  ! CDE $($c.name) failed $($r.StatusCode): $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" -ForegroundColor Yellow
  }
}

# ======= CUSTOM ATTRIBUTES =======
Write-Host "`n=== Creating Custom Attributes ===" -ForegroundColor Cyan
$attrs = @(
  @{ lob="Finance";    name="Reporting Pillar";         type="String"; def="Statutory"; desc="Reporting pillar (Statutory / Management / Regulatory / ESG)." },
  @{ lob="Finance";    name="Materiality Tier";         type="String"; def="Tier 2";    desc="Materiality classification for SOX / financial-control scope (Tier 1/2/3)." },
  @{ lob="Customer";   name="Channel";                  type="String"; def="Web";       desc="Acquisition channel (Web / Partner / Direct / Outbound)." },
  @{ lob="Customer";   name="Consent Status";           type="String"; def="Granted";   desc="GDPR consent status for marketing usage (Granted / Withdrawn / Pending)." },
  @{ lob="HR";         name="Confidentiality Class";    type="String"; def="Confidential"; desc="Access classification (Public / Internal / Confidential / Restricted-HR)." },
  @{ lob="HR";         name="Workforce Segment";        type="String"; def="Permanent"; desc="Permanent / Contractor / Intern / Apprentice." },
  @{ lob="Operations"; name="Site Code";                type="String"; def="";          desc="Plant / site identifier for operational assets and reporting." },
  @{ lob="Operations"; name="Criticality Class";        type="String"; def="B";         desc="Equipment criticality (A=mission-critical / B=important / C=standard)." },
  @{ lob="Technology"; name="Certification Level";      type="String"; def="Bronze";    desc="Data product certification (Bronze / Silver / Gold)." },
  @{ lob="Technology"; name="Refresh Frequency";        type="String"; def="Daily";     desc="Expected refresh cadence (Realtime / Hourly / Daily / Weekly / Monthly)." }
)

$createdAttrs = 0
foreach ($a in $attrs) {
  $newId = [guid]::NewGuid().ToString()
  $body = @{ id=$newId; name=$a.name; description=$a.desc; fieldType=$a.type; defaultValue=$a.def; domain=$LoB[$a.lob]; isOptional=$true; status="Published" } | ConvertTo-Json -Depth 6
  $r = Invoke-WebRequest "$base/datagovernance/catalog/attributes/$newId$api" -Headers $headers -Method PUT -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -in 200,201) {
    $createdAttrs++
    Write-Host "  + Attr [$($a.lob)] $($a.name)" -ForegroundColor Green
  } else {
    $msg = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    Write-Host "  ! Attr $($a.name) failed $($r.StatusCode): $($msg.Substring(0,[Math]::Min(200,$msg.Length)))" -ForegroundColor Yellow
  }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Objectives: $($createdObjs.Count) | CDEs: $createdCdes | Attributes: $createdAttrs" -ForegroundColor Green
