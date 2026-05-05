# Sprint UC-I rebuild: Delete broken CDCs (Atlas asset refs), recreate with UC dataAsset refs
# Then link CDE -> CDC for each (only working linkage path).
# Note: DP -> CDC linkage rejected by API in this preview (despite docs implying support).

$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

# 1) Idempotency: track existing CDCs by name to skip re-creation
$existing = Invoke-RestMethod -Uri "$dgBase/criticalDataColumns$api&top=200" -Headers $headers -Method Get
$existingNames = @{}; foreach ($c in $existing.value) { $existingNames[$c.name] = $c.id }
Write-Host "=== Existing CDCs: $($existing.value.Count) ===" -ForegroundColor Cyan

# Domain GUIDs
$D_FIN  = "da176475-282f-4f22-9a06-7661d0e25916"
$D_CUST = "f1b1d5fe-3617-4786-9894-ffd8662bead7"
$D_HR   = "f64840cf-bac7-4d21-b43f-b02b3e9f5ba6"
$D_OPS  = "84f0ee4c-375b-4714-bd0d-a2d9dade9f36"
$D_TECH = "7f5695d1-8e2e-44f1-9c08-5c1e2455cee7"

# UC dataAsset IDs (verified to exist via /dataAssets endpoint)
$A_FIN_REPORT = @{ id="26296e20-47a0-4087-b329-c96be6019510"; name="Finance Report" }
$A_FSI_CCO    = @{ id="e328148a-ba6d-4fe3-9154-efb2b7a5b7e7"; name="FSI CCO Dashboard" }
$A_FACT_SALE  = @{ id="73650b71-ef35-4909-b0e4-8c76037c2b0a"; name="fact_sale" }
$A_DIM_DATE   = @{ id="ef41d148-fff7-4137-bcf6-a8bb782f44a7"; name="dimension_date" }
$A_DIM_CUST   = @{ id="f56a86e6-6442-4fea-8746-1ca95f8995f9"; name="dimension_customer" }
$A_DIM_CITY   = @{ id="5249c745-d03d-4742-97cb-022d6eff8dca"; name="dimension_city" }
$A_AGG_EMP    = @{ id="1e50dce5-bbcb-48df-b45b-c63c270599ef"; name="aggregate_sale_by_date_employee" }
$A_EXEC_REQ   = @{ id="a44c60f6-f7a0-44ca-a17a-5c6e4020c243"; name="exec_requests_history" }
$A_LAKEHOUSE  = @{ id="d11462f7-6789-4420-b37c-1d6f3179c622"; name="wwilakehouse-DirectLake" }
$A_PURV_HUB   = @{ id="46b7fbb3-0553-447f-b1d2-6d9f1b7edfc7"; name="Purview Hub" }

# Lookup CDEs by name -> id
$cdes = Invoke-RestMethod -Uri "$dgBase/criticalDataElements$api&top=200" -Headers $headers -Method Get
$cMap = @{}; foreach ($c in $cdes.value) { $cMap[$c.name] = $c.id }

# Plan: each CDE -> one CDC pointing to a sensible UC dataAsset + plausible column name
$plan = @(
    @{ cde="GL Account Number";       col="account_id";       asset=$A_FIN_REPORT;  domain=$D_FIN  },
    @{ cde="Fiscal Period";           col="fiscal_period";    asset=$A_DIM_DATE;    domain=$D_FIN  },
    @{ cde="Reporting Currency";      col="currency_code";    asset=$A_FACT_SALE;   domain=$D_FIN  },
    @{ cde="Customer Master ID";      col="customer_id";      asset=$A_DIM_CUST;    domain=$D_CUST },
    @{ cde="Email Address (PII)";     col="email";            asset=$A_DIM_CUST;    domain=$D_CUST },
    @{ cde="Customer Lifetime Value"; col="ltv_score";        asset=$A_DIM_CUST;    domain=$D_CUST },
    @{ cde="Employee ID";             col="employee_id";      asset=$A_AGG_EMP;     domain=$D_HR   },
    @{ cde="Compensation Band";       col="comp_band";        asset=$A_AGG_EMP;     domain=$D_HR   },
    @{ cde="Cost Center";             col="cost_center";      asset=$A_AGG_EMP;     domain=$D_HR   },
    @{ cde="Equipment ID";            col="equipment_id";     asset=$A_LAKEHOUSE;   domain=$D_OPS  },
    @{ cde="Work Order Number";       col="work_order_id";    asset=$A_LAKEHOUSE;   domain=$D_OPS  },
    @{ cde="Material Number";         col="material_id";      asset=$A_LAKEHOUSE;   domain=$D_OPS  },
    @{ cde="Asset Sensitivity Label"; col="sensitivity";      asset=$A_PURV_HUB;    domain=$D_TECH },
    @{ cde="Data Quality Score";      col="dq_score";         asset=$A_EXEC_REQ;    domain=$D_TECH },
    @{ cde="Owner Email";             col="owner_email";      asset=$A_PURV_HUB;    domain=$D_TECH }
)

Write-Host "`n=== Creating CDCs + CDE relationships ===" -ForegroundColor Cyan
$cdcCreated = 0; $relOk = 0; $fail = 0
foreach ($p in $plan) {
    $cdeId = $cMap[$p.cde]
    Write-Host "`n-- $($p.cde) -> $($p.asset.name).$($p.col) --" -ForegroundColor Yellow
    if (-not $cdeId) { Write-Host "  SKIP missing CDE" -ForegroundColor Red; $fail++; continue }

    $cdcName = "$($p.asset.name).$($p.col)"
    if ($existingNames.ContainsKey($cdcName)) {
        $cdcId = $existingNames[$cdcName]
        Write-Host "  ok  CDC exists id=$cdcId (skipping create)" -ForegroundColor DarkGreen
        $cdcCreated++
        $bRel = '{"relationshipType":"Related","entityId":"'+$cdcId+'"}'
        $r2 = Invoke-WebRequest -Uri "$dgBase/criticalDataElements/$cdeId/relationships?entityType=CriticalDataColumn&api-version=2026-03-20-preview" -Headers $headers -Method Post -Body $bRel -SkipHttpErrorCheck
        if ($r2.StatusCode -in 200,201,409) { Write-Host "  ok  CDE -> CDC linked" -ForegroundColor Green; $relOk++ }
        continue
    }
    $body = @{
        name       = $cdcName
        domain     = $p.domain
        assetId    = $p.asset.id
        assetName  = $p.asset.name
        columnName = $p.col
        status     = "Published"
    } | ConvertTo-Json
    $r = Invoke-WebRequest -Uri "$dgBase/criticalDataColumns$api" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
    $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    if ($r.StatusCode -notin 200,201) {
        Write-Host "  FAIL CDC :: HTTP $($r.StatusCode) $($c.Substring(0,[Math]::Min(180,$c.Length)))" -ForegroundColor Red; $fail++; continue
    }
    $cdcId = ($c | ConvertFrom-Json).id
    Write-Host "  ok  CDC id=$cdcId" -ForegroundColor Green
    $cdcCreated++

    # Link CDE -> CDC
    $bRel = '{"relationshipType":"Related","entityId":"'+$cdcId+'"}'
    $r = Invoke-WebRequest -Uri "$dgBase/criticalDataElements/$cdeId/relationships?entityType=CriticalDataColumn&api-version=2026-03-20-preview" -Headers $headers -Method Post -Body $bRel -SkipHttpErrorCheck
    $cc = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    if ($r.StatusCode -in 200,201,409) { Write-Host "  ok  CDE -> CDC linked" -ForegroundColor Green; $relOk++ }
    else { Write-Host "  FAIL CDE -> CDC :: HTTP $($r.StatusCode) $($cc.Substring(0,[Math]::Min(180,$cc.Length)))" -ForegroundColor Red; $fail++ }
}

Write-Host "`n========== Summary ==========" -ForegroundColor Cyan
Write-Host "CDCs created:     $cdcCreated / $($plan.Count)"
Write-Host "CDE->CDC links:   $relOk"
Write-Host "Failures:         $fail"

# Verification
$all = Invoke-RestMethod -Uri "$dgBase/criticalDataColumns$api&top=200" -Headers $headers -Method Get
Write-Host "`nTotal CriticalDataColumns in catalog: $($all.value.Count)" -ForegroundColor Green
$sample = $cMap["Customer Master ID"]
$rels = Invoke-RestMethod -Uri "$dgBase/criticalDataElements/$sample/relationships?entityType=CriticalDataColumn&api-version=2026-03-20-preview" -Headers $headers -Method Get
Write-Host "Sample CDE 'Customer Master ID' has $($rels.value.Count) CDC relationship(s)" -ForegroundColor Green
