param(
  [string]$PurviewAccount = "pdedemopurv",
  [int]$PerSystemLimit = 30,
  [string]$OutJson = "docs/lineage_review_2026-06-02.json",
  [string]$OutMd = "docs/lineage_review_2026-06-02.md"
)

$ErrorActionPreference = "Continue"

$base = "https://$PurviewAccount.purview.azure.com"
$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Search-Assets {
  param([string]$Keyword, [int]$Limit = 30)
  $body = @{ keywords = $Keyword; limit = $Limit } | ConvertTo-Json -Compress
  try {
    $r = Invoke-RestMethod -Uri "$base/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body
    return @($r.value)
  } catch {
    Write-Host "Search failed for '$Keyword': $($_.Exception.Message)" -ForegroundColor Red
    return @()
  }
}

function Filter-SystemAssets {
  param(
    [object[]]$Assets,
    [string]$SystemKey
  )

  switch ($SystemKey) {
    "salesforce" {
      return @($Assets | Where-Object {
        ($_.entityType -match "salesforce") -or ([string]$_.qualifiedName).ToLowerInvariant().Contains("salesforce")
      })
    }
    "snowflake" {
      return @($Assets | Where-Object {
        ($_.entityType -match "snowflake|ProcessCustomSnowflake") -or ([string]$_.qualifiedName).ToLowerInvariant().Contains("snowflake")
      })
    }
    "powerbi" {
      return @($Assets | Where-Object {
        $_.entityType -in @("powerbi_report", "powerbi_dataset", "powerbi_dashboard", "powerbi_dataflow", "powerbi_datamart")
      })
    }
    default { return @($Assets) }
  }
}

function Get-LineageSummary {
  param([string]$Guid)

  $url = "$base/catalog/api/atlas/v2/lineage/${Guid}?direction=BOTH&depth=5"
  try {
    $lin = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $rels = @($lin.relations).Count + @($lin.parentRelations).Count
    $entityMap = @{}
    if ($lin.guidEntityMap) { $entityMap = $lin.guidEntityMap }
    $entityCount = @($entityMap.PSObject.Properties).Count

    $tags = @()
    foreach ($p in $entityMap.PSObject.Properties) {
      $e = $p.Value
      $typeName = [string]$e.typeName
      $qName = [string]$e.attributes.qualifiedName
      $name = [string]$e.attributes.name
      $blob = ($typeName + " " + $qName + " " + $name).ToLowerInvariant()

      if ($blob -match "salesforce") { $tags += "salesforce" }
      if ($blob -match "snowflake") { $tags += "snowflake" }
      if ($blob -match "powerbi|power bi|pbir|pbi") { $tags += "powerbi" }
    }

    return [PSCustomObject]@{
      relationCount = $rels
      entityCount = $entityCount
      hasLineage = ($rels -gt 0 -or $entityCount -gt 1)
      systemsInGraph = @($tags | Sort-Object -Unique)
    }
  } catch {
    return [PSCustomObject]@{
      relationCount = -1
      entityCount = 0
      hasLineage = $false
      systemsInGraph = @()
      error = $_.Exception.Message
    }
  }
}

$systems = @(
  @{ key = "salesforce"; query = "salesforce" },
  @{ key = "snowflake"; query = "snowflake" },
  @{ key = "powerbi"; query = "powerbi" }
)

$reviewRows = @()

foreach ($s in $systems) {
  Write-Host "Scanning $($s.key)..." -ForegroundColor Cyan
  $rawAssets = Search-Assets -Keyword $s.query -Limit 200
  $assets = @(Filter-SystemAssets -Assets $rawAssets -SystemKey $s.key | Select-Object -First $PerSystemLimit)

  foreach ($a in $assets) {
    $guid = [string]$a.id
    if ([string]::IsNullOrWhiteSpace($guid)) { continue }

    $sum = Get-LineageSummary -Guid $guid
    $reviewRows += [PSCustomObject]@{
      sourceSystem = $s.key
      id = $guid
      name = [string]$a.name
      entityType = [string]$a.entityType
      qualifiedName = [string]$a.qualifiedName
      relationCount = $sum.relationCount
      entityCount = $sum.entityCount
      hasLineage = $sum.hasLineage
      systemsInGraph = ($sum.systemsInGraph -join ",")
      error = [string]$sum.error
    }
  }
}

# Remove duplicate assets encountered across searches
$reviewRows = $reviewRows | Sort-Object id -Unique

function Build-Stats {
  param([object[]]$Rows, [string]$System)
  $subset = @($Rows | Where-Object { $_.sourceSystem -eq $System })
  $total = $subset.Count
  $withLineage = @($subset | Where-Object { $_.hasLineage }).Count
  $crossToSnowflake = @($subset | Where-Object { $_.systemsInGraph -match "snowflake" }).Count
  $crossToPowerBI = @($subset | Where-Object { $_.systemsInGraph -match "powerbi" }).Count
  $crossToSalesforce = @($subset | Where-Object { $_.systemsInGraph -match "salesforce" }).Count

  [PSCustomObject]@{
    system = $System
    totalAssetsChecked = $total
    assetsWithLineage = $withLineage
    lineageCoveragePct = if ($total -gt 0) { [math]::Round(($withLineage * 100.0 / $total), 1) } else { 0 }
    graphsContainingSalesforce = $crossToSalesforce
    graphsContainingSnowflake = $crossToSnowflake
    graphsContainingPowerBI = $crossToPowerBI
  }
}

$stats = @(
  Build-Stats -Rows $reviewRows -System "salesforce"
  Build-Stats -Rows $reviewRows -System "snowflake"
  Build-Stats -Rows $reviewRows -System "powerbi"
)

$endToEnd = @($reviewRows | Where-Object {
  $_.systemsInGraph -match "salesforce" -and $_.systemsInGraph -match "snowflake" -and $_.systemsInGraph -match "powerbi"
}).Count

$report = [PSCustomObject]@{
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  purviewAccount = $PurviewAccount
  perSystemLimit = $PerSystemLimit
  stats = $stats
  endToEndGraphsCount = $endToEnd
  sampleRows = $reviewRows
}

$report | ConvertTo-Json -Depth 8 | Out-File -FilePath $OutJson -Encoding utf8

$lines = @()
$lines += "# Full Lineage Review"
$lines += ""
$lines += "Generated at (UTC): $($report.generatedAtUtc)"
$lines += "Purview account: $PurviewAccount"
$lines += "Assets checked per system target: $PerSystemLimit"
$lines += ""
$lines += "## Coverage Summary"
$lines += ""
$lines += "| System | Checked | With Lineage | Coverage % | Graphs w/ Salesforce | Graphs w/ Snowflake | Graphs w/ Power BI |"
$lines += "|---|---:|---:|---:|---:|---:|---:|"
foreach ($s in $stats) {
  $lines += "| $($s.system) | $($s.totalAssetsChecked) | $($s.assetsWithLineage) | $($s.lineageCoveragePct) | $($s.graphsContainingSalesforce) | $($s.graphsContainingSnowflake) | $($s.graphsContainingPowerBI) |"
}
$lines += ""
$lines += "End-to-end graphs containing Salesforce + Snowflake + Power BI: $endToEnd"
$lines += ""
$lines += "## Top Gaps (first 20 rows without lineage)"
$lines += ""
$lines += "| System | Name | Type | Relation Count | Error |"
$lines += "|---|---|---|---:|---|"
$gaps = @($reviewRows | Where-Object { -not $_.hasLineage } | Select-Object -First 20)
foreach ($g in $gaps) {
  $name = ($g.name -replace "\|", "/")
  $type = ($g.entityType -replace "\|", "/")
  $err = (($g.error -replace "\|", "/") -replace "\r|\n", " ")
  $lines += "| $($g.sourceSystem) | $name | $type | $($g.relationCount) | $err |"
}

$lines -join "`n" | Out-File -FilePath $OutMd -Encoding utf8

Write-Host "Review complete." -ForegroundColor Green
Write-Host "JSON: $OutJson"
Write-Host "MD:   $OutMd"