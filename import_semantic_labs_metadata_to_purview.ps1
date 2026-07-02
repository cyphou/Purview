param(
  [Parameter(Mandatory = $true)][string]$MetadataJsonPath,
  [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$atlasBase = "$base/catalog/api/atlas/v2"

$datasetGuid = "0d401759-00e0-4dd7-a703-c65994568beb"
$datasetQn = "https://app.powerbi.com/groups/7000dcc5-3063-4dc7-99f5-965d551c2083/datasets/6b2e4d57-5492-4d99-85ec-1d23560b58a4"

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
if (-not $token) { throw "Could not acquire Purview token." }

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Get-EntityByGuid {
  param([Parameter(Mandatory = $true)][string]$Guid)
  $uri = "$atlasBase/entity/guid/${Guid}?api-version=2022-03-01-preview&minExtInfo=false&ignoreRelationships=false"
  return (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).entity
}

function Get-EntityByQualifiedName {
  param(
    [Parameter(Mandatory = $true)][string]$TypeName,
    [Parameter(Mandatory = $true)][string]$QualifiedName
  )
  $uri = "$atlasBase/entity/uniqueAttribute/type/$TypeName?attr:qualifiedName=$([uri]::EscapeDataString($QualifiedName))"
  try {
    return (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).entity
  } catch {
    return $null
  }
}

function Upsert-Entity {
  param([Parameter(Mandatory = $true)][hashtable]$Entity)

  $body = @{ entity = $Entity } | ConvertTo-Json -Depth 40
  $r = Invoke-WebRequest -Uri "$atlasBase/entity" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
  if ($r.StatusCode -notin 200, 201) {
    throw "Upsert failed ($($Entity.typeName)). HTTP $($r.StatusCode): $($content.Substring(0, [Math]::Min(600, $content.Length)))"
  }
}

function Ensure-PowerBiTable {
  param(
    [Parameter(Mandatory = $true)][string]$TableQualifiedName,
    [Parameter(Mandatory = $true)][string]$TableName,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $existing = Get-EntityByQualifiedName -TypeName "powerbi_table" -QualifiedName $TableQualifiedName
  if ($existing) {
    return $existing
  }

  $entity = @{
    typeName = "powerbi_table"
    attributes = @{
      qualifiedName = $TableQualifiedName
      name = $TableName
      displayName = $TableName
      description = $Description
      userDescription = $Description
    }
    relationshipAttributes = @{
      dataset = @{ typeName = "powerbi_dataset"; guid = $datasetGuid }
    }
  }
  Upsert-Entity -Entity $entity
  return Get-EntityByQualifiedName -TypeName "powerbi_table" -QualifiedName $TableQualifiedName
}

function Ensure-PowerBiColumn {
  param(
    [Parameter(Mandatory = $true)][string]$TableQualifiedName,
    [Parameter(Mandatory = $true)][string]$ColumnQualifiedName,
    [Parameter(Mandatory = $true)][string]$ColumnName,
    [Parameter(Mandatory = $true)][string]$DataType,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $existing = Get-EntityByQualifiedName -TypeName "powerbi_column" -QualifiedName $ColumnQualifiedName
  if ($existing) {
    return $existing
  }

  $table = Get-EntityByQualifiedName -TypeName "powerbi_table" -QualifiedName $TableQualifiedName
  if (-not $table) {
    throw "Cannot create column '$ColumnName' because parent table '$TableQualifiedName' was not found."
  }

  $entity = @{
    typeName = "powerbi_column"
    attributes = @{
      qualifiedName = $ColumnQualifiedName
      name = $ColumnName
      dataType = $DataType
      description = $Description
      userDescription = $Description
    }
    relationshipAttributes = @{
      table = @{ typeName = "powerbi_table"; guid = [string]$table.guid }
    }
  }
  Upsert-Entity -Entity $entity
  return Get-EntityByQualifiedName -TypeName "powerbi_column" -QualifiedName $ColumnQualifiedName
}

if (-not (Test-Path -LiteralPath $MetadataJsonPath)) {
  throw "Metadata file not found: $MetadataJsonPath"
}

$semantic = Get-Content -LiteralPath $MetadataJsonPath -Raw | ConvertFrom-Json
$sourceLabel = if ($semantic.source) { [string]$semantic.source } else { "semantic-model-sync" }

Write-Host "=== Import Semantic Labs metadata into Purview ===" -ForegroundColor Cyan
Write-Host "Input: $MetadataJsonPath"
Write-Host "Dataset: $datasetQn"

$dataset = Get-EntityByGuid -Guid $datasetGuid

$measurePreview = @($semantic.measures | Select-Object -First 15)
$measureLines = @()
foreach ($m in $measurePreview) {
  $measureLines += "- [$($m.table)] $($m.name): $($m.description)"
}

$relationshipPreview = @($semantic.relationships | Select-Object -First 20)
$relationshipLines = @()
foreach ($r in $relationshipPreview) {
  $relationshipLines += "- $($r.fromTable).$($r.fromColumn) -> $($r.toTable).$($r.toColumn)"
}

$datasetDesc = @(
  "Semantic model metadata synchronized from $sourceLabel.",
  "Workspace: $($semantic.workspace)",
  "Dataset: $($semantic.dataset)",
  "Generated UTC: $($semantic.generatedAtUtc)",
  "",
  "Tables: $(@($semantic.tables).Count)",
  "Measures: $(@($semantic.measures).Count)",
  "Relationships: $(@($semantic.relationships).Count)",
  "Roles: $(@($semantic.roles).Count)",
  "",
  "Top measures:",
  ($measureLines -join "`n"),
  "",
  "Top relationships:",
  ($relationshipLines -join "`n")
) -join "`n"

$datasetEntity = @{
  typeName = "powerbi_dataset"
  guid = $datasetGuid
  attributes = @{
    qualifiedName = $datasetQn
    name = [string]$dataset.attributes.name
    displayName = [string]$dataset.attributes.displayName
    description = $datasetDesc
    userDescription = $datasetDesc
  }
}
Upsert-Entity -Entity $datasetEntity

$updatedColumns = 0
$updatedTables = 0

foreach ($tbl in @($semantic.tables)) {
  $tableQn = "$datasetQn/tables/$($tbl.name)"
  $table = Get-EntityByQualifiedName -TypeName "powerbi_table" -QualifiedName $tableQn

  $tableDesc = "Semantic Labs sync. Hidden=$($tbl.isHidden). Columns=$(@($tbl.columns).Count). Hierarchies=$(@($tbl.hierarchies).Count)."
  if ($tbl.description) {
    $tableDesc = "$($tbl.description)`n`n$tableDesc"
  }

  if (-not $table) {
    Write-Host "Skipping non-existent Purview table entity: $($tbl.name)"
    continue
  }

  $tableEntity = @{
    typeName = "powerbi_table"
    guid = [string]$table.guid
    attributes = @{
      qualifiedName = $tableQn
      name = [string]$table.attributes.name
      displayName = [string]$table.attributes.displayName
      description = $tableDesc
      userDescription = $tableDesc
    }
  }
  Upsert-Entity -Entity $tableEntity
  $updatedTables++

  foreach ($col in @($tbl.columns)) {
    $columnQn = "$tableQn/columns/$($col.name)"
    $column = Get-EntityByQualifiedName -TypeName "powerbi_column" -QualifiedName $columnQn

    $colDesc = "Semantic Labs sync. DataType=$($col.dataType); Hidden=$($col.isHidden); Format=$($col.formatString)"
    if ($col.description) {
      $colDesc = "$($col.description)`n`n$colDesc"
    }

    if (-not $column) {
      Write-Host "  Skipping non-existent Purview column entity: $($tbl.name).$($col.name)"
      continue
    }

    $colEntity = @{
      typeName = "powerbi_column"
      guid = [string]$column.guid
      attributes = @{
        qualifiedName = $columnQn
        name = [string]$column.attributes.name
        dataType = if ($col.dataType) { [string]$col.dataType } else { [string]$column.attributes.dataType }
        description = $colDesc
        userDescription = $colDesc
      }
    }
    Upsert-Entity -Entity $colEntity
    $updatedColumns++
  }
}

$datasetAfter = Get-EntityByGuid -Guid $datasetGuid
$processGuid = [string]$datasetAfter.relationshipAttributes.datasetProcess.guid
if ($processGuid) {
  $process = Get-EntityByGuid -Guid $processGuid

  $processDesc = @(
    "Semantic model process metadata synchronized from $sourceLabel.",
    "Relationships captured: $(@($semantic.relationships).Count)",
    "Roles captured: $(@($semantic.roles).Count)"
  ) -join "`n"

  $processEntity = @{
    typeName = "powerbi_dataset_process"
    guid = $processGuid
    attributes = @{
      qualifiedName = [string]$process.attributes.qualifiedName
      name = [string]$process.attributes.name
      displayName = "Finance Report Semantic Process ($sourceLabel)"
      description = $processDesc
      userDescription = $processDesc
    }
  }
  Upsert-Entity -Entity $processEntity
}

Write-Host "\n=== Completed ===" -ForegroundColor Green
Write-Host "Tables updated:  $updatedTables"
Write-Host "Columns updated: $updatedColumns"
Write-Host "Measures in source payload: $(@($semantic.measures).Count)"
