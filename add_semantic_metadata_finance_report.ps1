param(
  [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$atlasBase = "$base/catalog/api/atlas/v2"

$datasetGuid = "0d401759-00e0-4dd7-a703-c65994568beb"
$datasetQn = "https://app.powerbi.com/groups/7000dcc5-3063-4dc7-99f5-965d551c2083/datasets/6b2e4d57-5492-4d99-85ec-1d23560b58a4"
$tableQn = "$datasetQn/tables/FinanceModel"

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
if (-not $token) { throw "Could not acquire Purview access token." }

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
  param(
    [Parameter(Mandatory = $true)][hashtable]$Entity
  )

  $body = @{ entity = $Entity } | ConvertTo-Json -Depth 30
  $r = Invoke-WebRequest -Uri "$atlasBase/entity" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
  if ($r.StatusCode -notin 200, 201) {
    throw "Upsert failed for type=$($Entity.typeName) name=$($Entity.attributes.name). HTTP $($r.StatusCode) :: $($content.Substring(0, [Math]::Min(500, $content.Length)))"
  }
}

function Ensure-PowerBiColumn {
  param(
    [Parameter(Mandatory = $true)][string]$TableQualifiedName,
    [Parameter(Mandatory = $true)][string]$ColumnName,
    [Parameter(Mandatory = $true)][string]$DataType,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $columnQn = "$TableQualifiedName/columns/$ColumnName"
  $existing = Get-EntityByQualifiedName -TypeName "powerbi_column" -QualifiedName $columnQn
  if ($existing) {
    $entity = @{
      typeName = "powerbi_column"
      guid = [string]$existing.guid
      attributes = @{
        qualifiedName = $columnQn
        name = $ColumnName
        dataType = $DataType
        description = $Description
        userDescription = $Description
      }
    }
    Upsert-Entity -Entity $entity
    return [string]$existing.guid
  }

  $entity = @{
    typeName = "powerbi_column"
    attributes = @{
      qualifiedName = $columnQn
      name = $ColumnName
      dataType = $DataType
      description = $Description
      userDescription = $Description
    }
    relationshipAttributes = @{
      table = @{ typeName = "powerbi_table"; uniqueAttributes = @{ qualifiedName = $TableQualifiedName } }
    }
  }
  Upsert-Entity -Entity $entity

  $created = Get-EntityByQualifiedName -TypeName "powerbi_column" -QualifiedName $columnQn
  if ($created) { return [string]$created.guid }
  return $null
}

function Resolve-FinanceTable {
  param([string]$ExpectedQualifiedName)

  $table = Get-EntityByQualifiedName -TypeName "powerbi_table" -QualifiedName $ExpectedQualifiedName
  if ($table) { return $table }

  # In this tenant, powerbi_table uniqueAttribute lookup can return 404 even when entity exists.
  $fallbackGuids = @(
    "efdd504d-b671-4386-ba40-bbf6f6f60000"
  )
  foreach ($g in $fallbackGuids) {
    try {
      $t = Get-EntityByGuid -Guid $g
      if ($t -and [string]$t.typeName -eq "powerbi_table" -and [string]$t.attributes.qualifiedName -eq $ExpectedQualifiedName) {
        return $t
      }
    } catch {
    }
  }

  return $null
}

Write-Host "=== Enrich Finance Report semantic metadata ===" -ForegroundColor Cyan

$dataset = Get-EntityByGuid -Guid $datasetGuid

$datasetDescription = "Semantic model for Finance Report with curated customer and order KPIs. Includes dimensional customer context, order lifecycle metrics, and revenue measures used by Executive Financial Dashboards."
$datasetEntity = @{
  typeName = "powerbi_dataset"
  guid = $datasetGuid
  attributes = @{
    qualifiedName = $datasetQn
    name = $dataset.attributes.name
    displayName = "Finance Report"
    description = $datasetDescription
    userDescription = $datasetDescription
  }
}
Upsert-Entity -Entity $datasetEntity

$table = Resolve-FinanceTable -ExpectedQualifiedName $tableQn
if (-not $table) {
  $tableEntity = @{
    typeName = "powerbi_table"
    attributes = @{
      qualifiedName = $tableQn
      name = "FinanceModel"
      displayName = "FinanceModel"
      description = "Primary semantic table used by the Finance Report dataset."
      userDescription = "Primary semantic table used by the Finance Report dataset."
    }
    relationshipAttributes = @{
      dataset = @{ typeName = "powerbi_dataset"; uniqueAttributes = @{ qualifiedName = $datasetQn } }
    }
  }
  Upsert-Entity -Entity $tableEntity
  $table = Resolve-FinanceTable -ExpectedQualifiedName $tableQn
}

if (-not $table) { throw "Could not resolve FinanceModel table after upsert." }

$columnSpecs = @(
  @{ name = "CUSTOMER_ID"; dataType = "Int64"; desc = "Business customer key in the semantic layer. Mapped from Snowflake CUSTOMER.C_CUSTKEY and Salesforce CUSTOMER_ID." },
  @{ name = "CUSTOMER_NAME"; dataType = "String"; desc = "Customer display name used in financial segmentation and report slicing." },
  @{ name = "CUSTOMER_SEGMENT"; dataType = "String"; desc = "Commercial segment used for profitability and revenue breakdowns." },
  @{ name = "ORDER_ID"; dataType = "Int64"; desc = "Order identifier used to reconcile transactional financial records." },
  @{ name = "ORDER_DATE"; dataType = "DateTime"; desc = "Order creation date used for fiscal period aggregations." },
  @{ name = "TOTAL_REVENUE"; dataType = "Decimal"; desc = "Gross order amount before discount adjustments." },
  @{ name = "NET_REVENUE"; dataType = "Decimal"; desc = "Revenue net of discounts at line-item grain." },
  @{ name = "DISCOUNT_AMOUNT"; dataType = "Decimal"; desc = "Discount value used to derive net revenue and margin indicators." },
  @{ name = "SHIP_DATE"; dataType = "DateTime"; desc = "Shipment date used for operational and fulfillment lag analysis." },
  @{ name = "ORDER_STATUS"; dataType = "String"; desc = "Current order lifecycle status used in open/closed financial reporting." }
)

$columnGuids = @{}
foreach ($spec in $columnSpecs) {
  $guid = Ensure-PowerBiColumn -TableQualifiedName $tableQn -ColumnName $spec.name -DataType $spec.dataType -Description $spec.desc
  if ($guid) { $columnGuids[$spec.name] = $guid }
}

$tableEntityUpdate = @{
  typeName = "powerbi_table"
  guid = [string]$table.guid
  attributes = @{
    qualifiedName = $tableQn
    name = "FinanceModel"
    displayName = "FinanceModel"
    description = "Semantic table for customer, order, and revenue metrics powering Finance Report visuals."
    userDescription = "Semantic table for customer, order, and revenue metrics powering Finance Report visuals."
  }
}
Upsert-Entity -Entity $tableEntityUpdate

$datasetAfter = Get-EntityByGuid -Guid $datasetGuid
$datasetProcessGuid = [string]$datasetAfter.relationshipAttributes.datasetProcess.guid
if ($datasetProcessGuid) {
  $processMapping = @(
    @{ Source = @{ name = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_CUSTKEY"; type = "snowflake_table_column" }; Sink = @{ name = "$tableQn/columns/CUSTOMER_ID"; type = "powerbi_column" } },
    @{ Source = @{ name = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_NAME"; type = "snowflake_table_column" }; Sink = @{ name = "$tableQn/columns/CUSTOMER_NAME"; type = "powerbi_column" } },
    @{ Source = @{ name = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/ORDERS/columns/O_TOTALPRICE"; type = "snowflake_table_column" }; Sink = @{ name = "$tableQn/columns/TOTAL_REVENUE"; type = "powerbi_column" } },
    @{ Source = @{ name = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/LINEITEM/columns/L_EXTENDEDPRICE"; type = "snowflake_table_column" }; Sink = @{ name = "$tableQn/columns/NET_REVENUE"; type = "powerbi_column" } }
  ) | ConvertTo-Json -Depth 8 -Compress

  $processEntity = Get-EntityByGuid -Guid $datasetProcessGuid
  $processUpdate = @{
    typeName = "powerbi_dataset_process"
    guid = $datasetProcessGuid
    attributes = @{
      qualifiedName = [string]$processEntity.attributes.qualifiedName
      name = [string]$processEntity.attributes.name
      displayName = "Finance Report Semantic Process"
      description = "Semantic model process for Finance Report. Curates customer and order measures from Snowflake and aligns with Salesforce customer semantics."
      userDescription = "Semantic model process for Finance Report. Curates customer and order measures from Snowflake and aligns with Salesforce customer semantics."
      columnMapping = $processMapping
    }
  }
  Upsert-Entity -Entity $processUpdate
}

# Verification snapshot
$datasetCheck = Get-EntityByGuid -Guid $datasetGuid
$tableCheck = Resolve-FinanceTable -ExpectedQualifiedName $tableQn
$tableWithCols = if ($tableCheck) { Get-EntityByGuid -Guid ([string]$tableCheck.guid) } else { $null }

Write-Host "\n=== Verification ===" -ForegroundColor Green
Write-Host "Dataset: $($datasetCheck.displayText)"
Write-Host "Dataset description: $($datasetCheck.attributes.description)"
Write-Host "Table guid: $([string]$tableCheck.guid)"
Write-Host "Columns count on table: $(@($tableWithCols.relationshipAttributes.columns).Count)"

$previewCols = @($tableWithCols.relationshipAttributes.columns | Select-Object -First 10)
foreach ($c in $previewCols) {
  $ce = Get-EntityByGuid -Guid ([string]$c.guid)
  Write-Host (" - {0} [{1}]" -f $ce.attributes.name, $ce.attributes.dataType)
}

if ($datasetCheck.relationshipAttributes.datasetProcess.guid) {
  $proc = Get-EntityByGuid -Guid ([string]$datasetCheck.relationshipAttributes.datasetProcess.guid)
  Write-Host "Dataset process columnMapping length: $([string]$proc.attributes.columnMapping).Length"
}

Write-Host "\nMetadata enrichment completed." -ForegroundColor Green
