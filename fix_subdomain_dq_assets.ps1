param(
  [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Continue"

$base = "https://$PurviewAccount.purview.azure.com"
$dgBase = "$base/datagovernance/catalog"
$atlasBase = "$base/catalog/api/atlas/v2"
$api = "api-version=2026-03-20-preview"

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Ensure-DqType {
  param([string]$TypeName, [string]$Description)
  $typesUri = "$atlasBase/types/typedefs"
  $td = Invoke-RestMethod -Uri $typesUri -Headers $headers -Method Get
  $exists = @($td.classificationDefs | Where-Object { $_.name -eq $TypeName }).Count -gt 0
  if ($exists) { return }

  $body = @{
    classificationDefs = @(@{
      category = "CLASSIFICATION"
      name = $TypeName
      description = $Description
      typeVersion = "1.0"
      attributeDefs = @()
      superTypes = @()
    })
  } | ConvertTo-Json -Depth 8

  $r = Invoke-WebRequest -Uri $typesUri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -in 200,201) {
    Write-Host "created type: $TypeName" -ForegroundColor Green
  } else {
    Write-Host "warn type create $TypeName -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
  }
}

function Add-Relationship {
  param(
    [string]$DataProductId,
    [string]$EntityId,
    [string]$EntityType
  )

  $body = @{ entityId = $EntityId; relationshipType = "Related" } | ConvertTo-Json -Compress
  $uri = "$dgBase/dataproducts/$DataProductId/relationships?entityType=$EntityType&$api"
  $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  if ($r.StatusCode -in 200,201,409) { return $true }
  return $false
}

function Add-DqClassification {
  param(
    [string]$AtlasGuid,
    [string]$Tier
  )

  $body = @(@{ typeName = $Tier; propagate = $false }) | ConvertTo-Json -AsArray -Depth 4
  $uri = "$atlasBase/entity/guid/$AtlasGuid/classifications"
  $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  return ($r.StatusCode -in 200,204,409)
}

function Is-Guid {
  param([string]$Value)
  if (-not $Value) { return $false }
  return [System.Guid]::TryParse($Value, [ref]([guid]::Empty))
}

Ensure-DqType -TypeName "DQ_Gold" -Description "Demo DQ tier: score 90-100"
Ensure-DqType -TypeName "DQ_Silver" -Description "Demo DQ tier: score 75-89"
Ensure-DqType -TypeName "DQ_Bronze" -Description "Demo DQ tier: score <75"

$dpConfig = @{
  "Sales Pipeline Intelligence" = @{
    dqTier = "DQ_Gold"
    assetKeywords = @("sales", "pipeline", "opportunity", "lead", "customer")
    dqTerms = @("DQ_Gold", "Data Quality Score", "Data Quality Rule Coverage", "Data Freshness", "Data Accuracy")
  }
  "Pricing and Discount Effectiveness" = @{
    dqTier = "DQ_Silver"
    assetKeywords = @("price", "pricing", "discount", "sales", "revenue")
    dqTerms = @("DQ_Silver", "Data Quality Score", "Data Consistency", "Data Validity", "Data Freshness")
  }
  "Sell-out Performance Monitor" = @{
    dqTier = "DQ_Silver"
    assetKeywords = @("sell", "sales", "channel", "order", "customer")
    dqTerms = @("DQ_Silver", "Data Quality Rule Coverage", "Data Freshness", "Data Lineage", "Data Completeness")
  }
  "Customer Master Quality Hub" = @{
    dqTier = "DQ_Gold"
    assetKeywords = @("customer", "crm", "master", "consent", "profile")
    dqTerms = @("DQ_Gold", "Data Accuracy", "Data Completeness", "Data Consistency", "Data Quality Score")
  }
  "Consent and Preferences Compliance" = @{
    dqTier = "DQ_Gold"
    assetKeywords = @("consent", "preference", "customer", "gdpr", "crm")
    dqTerms = @("DQ_Gold", "Data Validity", "Data Consistency", "Data Completeness", "Data Quality Score")
  }
}

$dps = (Invoke-RestMethod -Uri "$dgBase/dataproducts?$api&top=500" -Headers $headers -Method Get).value | Where-Object { $dpConfig.ContainsKey($_.name) }
$allAssets = (Invoke-RestMethod -Uri "$dgBase/dataAssets?$api&top=2000" -Headers $headers -Method Get).value
$allTerms = (Invoke-RestMethod -Uri "$dgBase/terms?$api&top=2000" -Headers $headers -Method Get).value

$termMap = @{}
foreach ($t in $allTerms) {
  if (-not $termMap.ContainsKey($t.name)) { $termMap[$t.name] = $t.id }
}

$linkedAssetCount = 0
$linkedTermCount = 0
$classifiedCount = 0

foreach ($dp in $dps) {
  $cfg = $dpConfig[$dp.name]
  Write-Host "`n>>> $($dp.name)" -ForegroundColor Cyan

  $existingAssets = @((Invoke-RestMethod -Uri "$dgBase/dataproducts/$($dp.id)/relationships?entityType=DataAsset&$api" -Headers $headers -Method Get).value)
  $existingAssetIds = @($existingAssets | ForEach-Object { $_.entityId })

  $existingTerms = @((Invoke-RestMethod -Uri "$dgBase/dataproducts/$($dp.id)/relationships?entityType=Term&$api" -Headers $headers -Method Get).value)
  $existingTermIds = @($existingTerms | ForEach-Object { $_.entityId })

  $matchedAssets = @()
  foreach ($kw in $cfg.assetKeywords) {
    $matchedAssets += $allAssets | Where-Object { $_.name -and $_.name.ToLower().Contains($kw.ToLower()) }
  }
  $matchedAssets = @($matchedAssets | Sort-Object id -Unique | Select-Object -First 8)

  foreach ($a in $matchedAssets) {
    if ($existingAssetIds -contains $a.id) { continue }
    if (Add-Relationship -DataProductId $dp.id -EntityId $a.id -EntityType "DataAsset") {
      $linkedAssetCount++
      Write-Host "  + asset: $($a.name)" -ForegroundColor Green
      $existingAssetIds += $a.id
    }
  }

  foreach ($termName in $cfg.dqTerms) {
    if (-not $termMap.ContainsKey($termName)) { continue }
    $termId = $termMap[$termName]
    if ($existingTermIds -contains $termId) { continue }
    if (Add-Relationship -DataProductId $dp.id -EntityId $termId -EntityType "Term") {
      $linkedTermCount++
      Write-Host "  + dq term: $termName" -ForegroundColor Green
      $existingTermIds += $termId
    }
  }

  # Re-read asset relationships and classify linked atlas assets
  $currentAssetRels = @((Invoke-RestMethod -Uri "$dgBase/dataproducts/$($dp.id)/relationships?entityType=DataAsset&$api" -Headers $headers -Method Get).value)
  foreach ($rel in $currentAssetRels) {
    $assetObj = $allAssets | Where-Object { $_.id -eq $rel.entityId } | Select-Object -First 1
    if (-not $assetObj) { continue }
    $atlasGuid = [string]$assetObj.source.assetId
    if (-not (Is-Guid -Value $atlasGuid)) { continue }

    if (Add-DqClassification -AtlasGuid $atlasGuid -Tier $cfg.dqTier) {
      $classifiedCount++
    }
  }
}

Write-Host "`n=== DQ Remediation Summary ===" -ForegroundColor Cyan
Write-Host "DataAsset links added: $linkedAssetCount"
Write-Host "DQ term links added:  $linkedTermCount"
Write-Host "Asset DQ tags applied: $classifiedCount"
