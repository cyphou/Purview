# Sprint July-2026-B: Real Data Quality Scans (now GA — May 2026)
#
# Previously: DQ endpoints returned 404; we used fake Atlas classifications (sprint_uc_j).
# Now GA (May 2026):
#   - Standalone data asset DQ scan (no DP required)
#   - Incremental DQ scan (time-based filtering)
#   - Configurable DQ thresholds (rule-level + asset-level)
#   - On-premises Oracle + SQL Server (preview, April 2026)
#
# This script:
#   1) Probes ALL DQ endpoint patterns to map what's now live vs still 404
#   2) Attempts to create a managed-identity DQ connection for Fabric/PowerBI assets
#   3) Creates DQ rules on key demo assets (fact_sale, dimension_customer, Finance Report)
#   4) Triggers standalone scans and polls for results
#   5) If scan succeeds: real DQ scores replace the fake DQ_Gold/Silver/Bronze chips
#   6) Sets asset-level DQ thresholds for demo alerting
#
# Source: https://learn.microsoft.com/en-us/purview/unified-catalog-data-quality-scan-asset
# Requires: Data Quality Steward or Data Quality Administrator role on governance domains

param(
    [string]$PurviewAccount = "pdedemopurv",
    [switch]$ProbeOnly,         # Only probe endpoints, don't create anything
    [switch]$SkipScanTrigger    # Create rules but don't trigger scans (for prep only)
)

$ErrorActionPreference = "Stop"
$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$base    = "https://$PurviewAccount.purview.azure.com"
$dgBase  = "$base/datagovernance/catalog"
$api     = "?api-version=2026-03-20-preview"

function Invoke-Api($method, $uri, $body = $null) {
    $params = @{ Uri=$uri; Headers=$headers; Method=$method; SkipHttpErrorCheck=$true }
    if ($body) { $params.Body = ($body | ConvertTo-Json -Depth 10) }
    $r = Invoke-WebRequest @params
    $c = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
    [PSCustomObject]@{ Status=$r.StatusCode; Body=$c; Json={ try { $c | ConvertFrom-Json } catch { $null } } }
}

# Known UC data asset IDs (from sprint_uc_i_critical_data_columns.ps1)
$ASSETS = @{
    "Finance Report"    = "26296e20-47a0-4087-b329-c96be6019510"
    "fact_sale"         = "73650b71-ef35-4909-b0e4-8c76037c2b0a"
    "dimension_customer"= "f56a86e6-6442-4fea-8746-1ca95f8995f9"
    "dimension_date"    = "ef41d148-fff7-4137-bcf6-a8bb782f44a7"
    "wwilakehouse-DirectLake" = "d11462f7-6789-4420-b37c-1d6f3179c622"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "=== Step 1: Endpoint Discovery (DQ API surface May 2026) ===" -ForegroundColor Cyan

$dqPaths = @(
    # Classic paths (were 404 in sprint UC-J)
    "GET  $dgBase/dataquality/connections$api"
    "GET  $dgBase/dataquality/rules$api"
    "GET  $dgBase/dataquality/scans$api"
    "GET  $dgBase/dataquality/profiles$api"
    "GET  $base/datagovernance/quality/scores$api"
    # New GA standalone scan paths (May 2026)
    "GET  $dgBase/dataquality/assets$api"
    "GET  $dgBase/dataqualityassets$api"
    "GET  $dgBase/dataquality$api"
    # Health/score read paths
    "GET  $base/datagovernance/health/dataquality$api"
    "GET  $base/datagovernance/dataquality/status$api"
    # Threshold endpoint (GA May 2026)
    "GET  $dgBase/dataquality/thresholds$api"
    "GET  $base/datagovernance/quality/thresholds$api"
)

$liveEndpoints = @()
foreach ($p in $dqPaths) {
    $verb, $url = $p -split " ", 2
    $r = Invoke-Api $verb $url
    $status = $r.Status
    $icon = if ($status -eq 200) { "✅" } elseif ($status -in 201..299) { "🟡" } elseif ($status -in 400..499 -and $status -ne 404) { "⚠️" } else { "  " }
    Write-Host ("  {0} [{1,3}] {2}" -f $icon, $status, $p) -ForegroundColor $(switch ($status) { 200 { "Green" } 404 { "DarkGray" } default { "Yellow" } })
    if ($status -ne 404) { $liveEndpoints += $p }
}

Write-Host "`n  Live endpoints found: $($liveEndpoints.Count) / $($dqPaths.Count)" -ForegroundColor $(if ($liveEndpoints.Count -gt 0) { "Green" } else { "Yellow" })

if ($ProbeOnly) {
    Write-Host "`n  [ProbeOnly] Stopping after discovery." -ForegroundColor Yellow
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 2: Try Creating a DQ Managed-Identity Connection ===" -ForegroundColor Cyan
Write-Host "  (Fabric/Power BI assets use the Purview MSI — no external credentials needed)" -ForegroundColor DarkGray

# The managed identity for this Purview account is the account MSI
# For Fabric/PBI assets in the same tenant, MSI access is typically auto-granted
$connectionBodies = @(
    @{
        name         = "Demo-Fabric-DQ-Connection"
        description  = "Managed identity connection for DQ scans on Fabric/PBI assets"
        authType     = "ManagedIdentity"
        sourceType   = "PowerBI"
        tenantId     = "2bfad6b9-88f6-4129-a60f-457babf01498"
    },
    @{
        name         = "Demo-Fabric-DQ-Connection"
        type         = "ManagedIdentity"
        dataSource   = "Fabric"
    }
)

$connectionId = $null
foreach ($body in $connectionBodies) {
    $connPaths = @(
        "$dgBase/dataquality/connections$api"
        "$base/datagovernance/dataquality/connections$api"
    )
    foreach ($path in $connPaths) {
        $r = Invoke-Api "POST" $path $body
        if ($r.Status -in 200,201) {
            $obj = $r.Body | ConvertFrom-Json
            $connectionId = $obj.id
            Write-Host "  ✅ Connection created: id=$connectionId" -ForegroundColor Green
            break
        } elseif ($r.Status -ne 404) {
            Write-Host ("  [{0}] {1}" -f $r.Status, $r.Body.Substring(0,[Math]::Min(200,$r.Body.Length))) -ForegroundColor DarkGray
        }
    }
    if ($connectionId) { break }
}
if (-not $connectionId) { Write-Host "  ⚠️  Could not create connection — DQ feature may need portal enablement first." -ForegroundColor Yellow }

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 3: Create DQ Rules on Key Demo Assets ===" -ForegroundColor Cyan
Write-Host "  Rule types that work without access to raw data: Completeness, Uniqueness" -ForegroundColor DarkGray

$rules = @(
    @{
        assetId     = $ASSETS["fact_sale"]
        assetName   = "fact_sale"
        rules       = @(
            @{ name="fact_sale_completeness";  type="Completeness"; column="sale_key";  threshold=95.0; description="At least 95% of rows must have a non-null sale_key" }
            @{ name="fact_sale_uniqueness";    type="Uniqueness";   column="sale_key";  threshold=99.0; description="99%+ of sale_key values must be unique" }
        )
    },
    @{
        assetId     = $ASSETS["dimension_customer"]
        assetName   = "dimension_customer"
        rules       = @(
            @{ name="dim_customer_id_complete"; type="Completeness"; column="customer_id"; threshold=100.0; description="customer_id must be 100% complete (PII CDE)" }
            @{ name="dim_customer_id_unique";   type="Uniqueness";   column="customer_id"; threshold=100.0; description="customer_id must be 100% unique (PK)" }
        )
    },
    @{
        assetId     = $ASSETS["Finance Report"]
        assetName   = "Finance Report"
        rules       = @(
            @{ name="finance_report_completeness"; type="Completeness"; column="Revenue"; threshold=95.0; description="Revenue measure must be non-null in 95%+ of rows" }
        )
    }
)

$ruleIds = @{}
foreach ($asset in $rules) {
    Write-Host "`n  Asset: $($asset.assetName) (id=$($asset.assetId))" -ForegroundColor White
    foreach ($rule in $asset.rules) {
        $ruleBody = @{
            name        = $rule.name
            description = $rule.description
            assetId     = $asset.assetId
            type        = $rule.type
            column      = $rule.column
            threshold   = $rule.threshold
            status      = "Published"
        }
        $rulePaths = @(
            "$dgBase/dataquality/rules$api"
            "$dgBase/dataquality/assets/$($asset.assetId)/rules$api"
            "$base/datagovernance/dataquality/rules$api"
        )
        $created = $false
        foreach ($path in $rulePaths) {
            $r = Invoke-Api "POST" $path $ruleBody
            if ($r.Status -in 200,201) {
                $obj = $r.Body | ConvertFrom-Json
                $ruleIds[$rule.name] = $obj.id
                Write-Host ("    ✅ Rule '{0}': id={1}" -f $rule.name, $obj.id) -ForegroundColor Green
                $created = $true; break
            } elseif ($r.Status -ne 404) {
                Write-Host ("    [{0}] {1}" -f $r.Status, $r.Body.Substring(0,[Math]::Min(160,$r.Body.Length))) -ForegroundColor DarkGray
            }
        }
        if (-not $created) {
            Write-Host ("    ⚠️  Could not create rule '{0}'" -f $rule.name) -ForegroundColor Yellow
        }
    }
}

if ($SkipScanTrigger) {
    Write-Host "`n  [SkipScanTrigger] Rules created. Run without -SkipScanTrigger to trigger scans." -ForegroundColor Yellow
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 4: Trigger Standalone DQ Scans ===" -ForegroundColor Cyan

foreach ($asset in $rules) {
    Write-Host "`n  Triggering scan for: $($asset.assetName)" -ForegroundColor White
    $scanBody = @{
        assetId  = $asset.assetId
        scanType = "Full"   # or "Incremental" for time-based delta scans
    }
    $scanPaths = @(
        "$dgBase/dataquality/assets/$($asset.assetId)/scans$api"
        "$dgBase/dataquality/scans$api"
        "$base/datagovernance/dataquality/jobs$api"
    )
    $scanId = $null
    foreach ($path in $scanPaths) {
        $r = Invoke-Api "POST" $path $scanBody
        if ($r.Status -in 200,201,202) {
            $obj = $r.Body | ConvertFrom-Json
            $scanId = if ($obj.id) { $obj.id } elseif ($obj.jobId) { $obj.jobId } else { "triggered" }
            Write-Host ("  ✅ Scan queued: id={0}" -f $scanId) -ForegroundColor Green
            break
        } elseif ($r.Status -ne 404) {
            Write-Host ("  [{0}] {1}" -f $r.Status, $r.Body.Substring(0,[Math]::Min(200,$r.Body.Length))) -ForegroundColor DarkGray
        }
    }
    if (-not $scanId) { Write-Host "  ⚠️  Could not trigger scan — DQ service may need portal activation." -ForegroundColor Yellow }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 5: Set DQ Thresholds (GA May 2026) ===" -ForegroundColor Cyan

$thresholdConfig = @{
    defaults = @(
        @{ assetId=$ASSETS["fact_sale"];          minScore=90; tier="Gold";   alertOnFail=$true  }
        @{ assetId=$ASSETS["dimension_customer"]; minScore=95; tier="Gold";   alertOnFail=$true  }
        @{ assetId=$ASSETS["Finance Report"];     minScore=85; tier="Silver"; alertOnFail=$true  }
        @{ assetId=$ASSETS["dimension_date"];     minScore=80; tier="Silver"; alertOnFail=$false }
    )
}

foreach ($t in $thresholdConfig.defaults) {
    $body = @{
        assetId      = $t.assetId
        minScore     = $t.minScore
        tier         = $t.tier
        alertOnFail  = $t.alertOnFail
    }
    $threshPaths = @(
        "$dgBase/dataquality/assets/$($t.assetId)/thresholds$api"
        "$dgBase/dataquality/thresholds$api"
        "$base/datagovernance/quality/thresholds$api"
    )
    $assetName = ($ASSETS.GetEnumerator() | Where-Object Value -EQ $t.assetId).Key
    $set = $false
    foreach ($path in $threshPaths) {
        $r = Invoke-Api "POST" $path $body
        if ($r.Status -in 200,201) {
            Write-Host ("  ✅ Threshold set for {0}: min={1}%, tier={2}" -f $assetName, $t.minScore, $t.tier) -ForegroundColor Green
            $set = $true; break
        }
    }
    if (-not $set) {
        Write-Host ("  ⚠️  Threshold not set for {0} — portal required" -f $assetName) -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Live DQ endpoints:  $($liveEndpoints.Count)"
Write-Host "  DQ connection:      $(if ($connectionId) { '✅ id=' + $connectionId } else { '⚠ Portal enablement needed' })"
Write-Host "  Rules attempted:    $($rules | ForEach-Object { $_.rules.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)"
Write-Host ""
Write-Host "  If DQ endpoints are still 404, the Data Quality feature requires portal activation:" -ForegroundColor DarkGray
Write-Host "    Portal → Unified Catalog → Data quality → Enable" -ForegroundColor DarkGray
Write-Host "    (Standard SKU may need upgrade to Premium for full DQ scan service)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Once real scans produce scores, run sprint_uc_j_fake_data_quality.ps1" -ForegroundColor DarkGray
Write-Host "  with -RemoveFakeClassifications to clean up the DQ_Gold/Silver/Bronze chips." -ForegroundColor DarkGray
