param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$OutputDir = "docs"
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$ucApi = "2026-03-20-preview"

function Get-PurviewHeaders {
    $token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
    if (-not $token) {
        throw "Unable to get access token. Run 'az login' and retry."
    }
    return @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
}

function Get-DqTierFromClassifications {
    param([object[]]$Classifications)

    if (-not $Classifications) {
        return $null
    }

    $typeNames = @($Classifications | ForEach-Object { $_.typeName })
    if ($typeNames -contains "DQ_Gold") { return "DQ_Gold" }
    if ($typeNames -contains "DQ_Silver") { return "DQ_Silver" }
    if ($typeNames -contains "DQ_Bronze") { return "DQ_Bronze" }
    return $null
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$headers = Get-PurviewHeaders
$now = Get-Date

$allDataProducts = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/dataproducts?api-version=$ucApi&top=500" -Headers $headers -Method Get).value
$allAssets = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/dataAssets?api-version=$ucApi&top=5000" -Headers $headers -Method Get).value
$allTerms = (Invoke-RestMethod -Uri "$base/datagovernance/catalog/terms?api-version=$ucApi&top=5000" -Headers $headers -Method Get).value

$assetById = @{}
foreach ($a in $allAssets) {
    if ($a.id) { $assetById[$a.id] = $a }
}

$termById = @{}
foreach ($t in $allTerms) {
    if ($t.id) { $termById[$t.id] = $t }
}

$targetNames = @(
    "Executive Financial Dashboards",
    "ESG and CSRD Reporting Pack",
    "Customer 360",
    "Workforce Analytics",
    "Workforce Analytics Dashboard",
    "Operational Performance Hub",
    "Data Platform Health",
    "Data Platform Health Monitor",
    "Convergence B2B",
    "RC Datahub Inspection",
    "Books Analytics &  Forecasting"
)

$targetDataProducts = @($allDataProducts | Where-Object { $targetNames -contains $_.name })

$rows = @()
$global = [ordered]@{
    dataProducts = 0
    linkedAssets = 0
    linkedTerms = 0
    dqTaggedAssets = 0
    dqGold = 0
    dqSilver = 0
    dqBronze = 0
    dqMissing = 0
}

foreach ($dp in ($targetDataProducts | Sort-Object name)) {
    $dpId = $dp.id
    $assetRels = @()
    $termRels = @()

    try {
        $assetRels = @((Invoke-RestMethod -Uri "$base/datagovernance/catalog/dataproducts/$dpId/relationships?api-version=$ucApi&entityType=DataAsset" -Headers $headers -Method Get).value)
    } catch {
        Write-Warning "Failed to read DataAsset relationships for '$($dp.name)': $($_.Exception.Message)"
    }

    try {
        $termRels = @((Invoke-RestMethod -Uri "$base/datagovernance/catalog/dataproducts/$dpId/relationships?api-version=$ucApi&entityType=Term" -Headers $headers -Method Get).value)
    } catch {
        Write-Warning "Failed to read Term relationships for '$($dp.name)': $($_.Exception.Message)"
    }

    $assetCount = 0
    $dqTagged = 0
    $dqGold = 0
    $dqSilver = 0
    $dqBronze = 0
    $dqMissing = 0
    $missingAssetNames = @()

    foreach ($rel in @($assetRels)) {
        $assetId = $rel.entityId
        if (-not $assetId) { continue }
        $asset = $assetById[$assetId]
        if (-not $asset) { continue }

        $assetCount++
        $atlasGuid = $asset.source.assetId
        if (-not $atlasGuid) {
            $dqMissing++
            $missingAssetNames += $asset.name
            continue
        }

        try {
            $atlasEntity = Invoke-RestMethod -Uri "$base/catalog/api/atlas/v2/entity/guid/${atlasGuid}?api-version=2022-03-01-preview" -Headers $headers -Method Get
            $classifications = @($atlasEntity.entity.classifications)
            if (-not $classifications -or $classifications.Count -eq 0) {
                $classifications = @($atlasEntity.classifications)
            }
            $tier = Get-DqTierFromClassifications -Classifications $classifications
            if ($tier) {
                $dqTagged++
                if ($tier -eq "DQ_Gold") { $dqGold++ }
                elseif ($tier -eq "DQ_Silver") { $dqSilver++ }
                elseif ($tier -eq "DQ_Bronze") { $dqBronze++ }
            } else {
                $dqMissing++
                $missingAssetNames += $asset.name
            }
        } catch {
            $dqMissing++
            $missingAssetNames += $asset.name
        }
    }

    $termCount = @($termRels).Count

    $rows += [pscustomobject]@{
        dataProduct = $dp.name
        linkedAssets = $assetCount
        linkedTerms = $termCount
        dqTaggedAssets = $dqTagged
        dqGold = $dqGold
        dqSilver = $dqSilver
        dqBronze = $dqBronze
        dqMissing = $dqMissing
        missingAssets = @($missingAssetNames | Sort-Object -Unique)
    }

    $global.dataProducts++
    $global.linkedAssets += $assetCount
    $global.linkedTerms += $termCount
    $global.dqTaggedAssets += $dqTagged
    $global.dqGold += $dqGold
    $global.dqSilver += $dqSilver
    $global.dqBronze += $dqBronze
    $global.dqMissing += $dqMissing
}

$report = [pscustomobject]@{
    generatedAt = $now.ToString("s")
    purviewAccount = $PurviewAccount
    summary = $global
    dataProducts = $rows
}

$jsonPath = Join-Path $OutputDir "dq_coverage_report.json"
$mdPath = Join-Path $OutputDir "dq_coverage_report.md"

$report | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $jsonPath -Encoding utf8

$md = @()
$md += "# Data Quality Coverage Report"
$md += ""
$md += "Generated: $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$md += "Purview account: $PurviewAccount"
$md += ""
$md += "## Global summary"
$md += ""
$md += "- Data Products analyzed: $($global.dataProducts)"
$md += "- Linked assets: $($global.linkedAssets)"
$md += "- Linked terms: $($global.linkedTerms)"
$md += "- Assets with DQ tag: $($global.dqTaggedAssets)"
$md += "- DQ_Gold: $($global.dqGold)"
$md += "- DQ_Silver: $($global.dqSilver)"
$md += "- DQ_Bronze: $($global.dqBronze)"
$md += "- Assets missing DQ tag: $($global.dqMissing)"
$md += ""
$md += "## Per data product"
$md += ""
$md += "| Data Product | Assets | Terms | DQ tagged | Gold | Silver | Bronze | Missing DQ |"
$md += "|---|---:|---:|---:|---:|---:|---:|---:|"
foreach ($r in ($rows | Sort-Object dataProduct)) {
    $md += "| $($r.dataProduct) | $($r.linkedAssets) | $($r.linkedTerms) | $($r.dqTaggedAssets) | $($r.dqGold) | $($r.dqSilver) | $($r.dqBronze) | $($r.dqMissing) |"
}

$rowsWithMissing = @($rows | Where-Object { $_.dqMissing -gt 0 })
if ($rowsWithMissing.Count -gt 0) {
    $md += ""
    $md += "## Missing DQ details"
    $md += ""
    foreach ($r in ($rowsWithMissing | Sort-Object dataProduct)) {
        $md += "### $($r.dataProduct)"
        foreach ($assetName in $r.missingAssets) {
            $md += "- $assetName"
        }
        $md += ""
    }
}

$md -join "`r`n" | Out-File -LiteralPath $mdPath -Encoding utf8

Write-Host "DQ coverage report generated:" -ForegroundColor Green
Write-Host "  - $jsonPath"
Write-Host "  - $mdPath"