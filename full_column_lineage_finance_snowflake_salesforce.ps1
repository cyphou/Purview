param(
  [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$atlasBase = "$base/catalog/api/atlas/v2"
$dgBase = "$base/datagovernance/catalog"
$apiUc = "api-version=2026-03-20-preview"

$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
if (-not $token) { throw "Unable to acquire Purview token." }

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Get-AtlasByQualifiedName {
  param(
    [Parameter(Mandatory = $true)][string]$TypeName,
    [Parameter(Mandatory = $true)][string]$QualifiedName
  )
  $qn = [uri]::EscapeDataString($QualifiedName)
  $uri = "$atlasBase/entity/uniqueAttribute/type/$TypeName?attr:qualifiedName=$qn"
  try {
    return (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).entity
  } catch {
    return $null
  }
}

function Ensure-AtlasEntity {
  param(
    [Parameter(Mandatory = $true)][string]$TypeName,
    [Parameter(Mandatory = $true)][string]$QualifiedName,
    [Parameter(Mandatory = $true)][string]$Name,
    [hashtable]$RelationshipAttributes,
    [hashtable]$AdditionalAttributes
  )

  $existing = Get-AtlasByQualifiedName -TypeName $TypeName -QualifiedName $QualifiedName
  if ($existing) {
    return $existing.guid
  }

  $attrs = @{ qualifiedName = $QualifiedName; name = $Name }
  if ($AdditionalAttributes) {
    foreach ($k in $AdditionalAttributes.Keys) {
      $attrs[$k] = $AdditionalAttributes[$k]
    }
  }

  $entity = @{ typeName = $TypeName; attributes = $attrs }
  if ($RelationshipAttributes) {
    $entity.relationshipAttributes = $RelationshipAttributes
  }

  $body = @{ entity = $entity } | ConvertTo-Json -Depth 30
  $r = Invoke-WebRequest -Uri "$atlasBase/entity" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
  if ($r.StatusCode -notin 200, 201) {
    throw "Failed to create $TypeName '$Name' ($QualifiedName). HTTP $($r.StatusCode) :: $($content.Substring(0, [Math]::Min(500, $content.Length)))"
  }

  $parsed = $content | ConvertFrom-Json
  $created = @($parsed.mutatedEntities.CREATE | Select-Object -First 1)
  if ($created.Count -gt 0 -and $created[0].guid) {
    return [string]$created[0].guid
  }

  $updated = @($parsed.mutatedEntities.UPDATE | Select-Object -First 1)
  if ($updated.Count -gt 0 -and $updated[0].guid) {
    return [string]$updated[0].guid
  }

  if ($parsed.guidAssignments) {
    $ga = $parsed.guidAssignments.PSObject.Properties | Select-Object -First 1
    if ($ga -and $ga.Value) {
      return [string]$ga.Value
    }
  }

  $createdEntity = Get-AtlasByQualifiedName -TypeName $TypeName -QualifiedName $QualifiedName
  if (-not $createdEntity) {
    throw "Entity creation for $TypeName '$Name' returned success but could not be resolved afterwards."
  }
  return $createdEntity.guid
}

function Resolve-AtlasGuid {
  param(
    [Parameter(Mandatory = $true)][string]$TypeName,
    [Parameter(Mandatory = $true)][string]$QualifiedName
  )

  $ent = Get-AtlasByQualifiedName -TypeName $TypeName -QualifiedName $QualifiedName
  if ($ent) {
    return [string]$ent.guid
  }

  $searchBody = @{
    keywords = $QualifiedName
    limit = 10
    filter = @{ entityType = $TypeName }
  } | ConvertTo-Json -Depth 8

  $search = Invoke-RestMethod -Uri "$base/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $searchBody
  $match = @($search.value | Where-Object { [string]$_.qualifiedName -eq $QualifiedName } | Select-Object -First 1)
  if ($match.Count -gt 0 -and $match[0].id) {
    return [string]$match[0].id
  }

  return $null
}

function Ensure-ProcessLineage {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessQualifiedName,
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][string]$InputType,
    [Parameter(Mandatory = $true)][string]$InputQualifiedName,
    [Parameter(Mandatory = $true)][string]$OutputType,
    [Parameter(Mandatory = $true)][string]$OutputQualifiedName,
    [string]$InputGuid,
    [string]$OutputGuid
  )

  $existing = Get-AtlasByQualifiedName -TypeName "Process" -QualifiedName $ProcessQualifiedName
  if ($existing) {
    return [string]$existing.guid
  }

  if (-not $InputGuid) {
    $InputGuid = Resolve-AtlasGuid -TypeName $InputType -QualifiedName $InputQualifiedName
  }
  if (-not $OutputGuid) {
    $OutputGuid = Resolve-AtlasGuid -TypeName $OutputType -QualifiedName $OutputQualifiedName
  }
  if (-not $InputGuid) { throw "Process input entity not found: $InputType :: $InputQualifiedName" }
  if (-not $OutputGuid) { throw "Process output entity not found: $OutputType :: $OutputQualifiedName" }

  $colMap = @(
    @{
      Source = @{ name = $InputQualifiedName; type = $InputType }
      Sink   = @{ name = $OutputQualifiedName; type = $OutputType }
    }
  ) | ConvertTo-Json -Depth 8 -Compress

  $attrs = @{
    qualifiedName = $ProcessQualifiedName
    name          = $ProcessName
    inputs        = @(@{ typeName = $InputType; guid = [string]$InputGuid })
    outputs       = @(@{ typeName = $OutputType; guid = [string]$OutputGuid })
    columnMapping = $colMap
  }

  $body = @{ entity = @{ typeName = "Process"; attributes = $attrs } } | ConvertTo-Json -Depth 30
  $r = Invoke-WebRequest -Uri "$atlasBase/entity" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
  if ($r.StatusCode -notin 200, 201) {
    throw "Failed to create process '$ProcessName'. HTTP $($r.StatusCode) :: $($content.Substring(0, [Math]::Min(500, $content.Length)))"
  }

  $parsed = $content | ConvertFrom-Json
  $created = @($parsed.mutatedEntities.CREATE | Select-Object -First 1)
  if ($created.Count -gt 0 -and $created[0].guid) {
    return [string]$created[0].guid
  }

  $updated = @($parsed.mutatedEntities.UPDATE | Select-Object -First 1)
  if ($updated.Count -gt 0 -and $updated[0].guid) {
    return [string]$updated[0].guid
  }

  if ($parsed.guidAssignments) {
    $ga = $parsed.guidAssignments.PSObject.Properties | Select-Object -First 1
    if ($ga -and $ga.Value) {
      return [string]$ga.Value
    }
  }

  $createdEntity = Get-AtlasByQualifiedName -TypeName "Process" -QualifiedName $ProcessQualifiedName
  if (-not $createdEntity) {
    throw "Process creation returned success but process was not found afterwards: $ProcessQualifiedName"
  }
  return [string]$createdEntity.guid
}

function Ensure-DataProductAssetLinks {
  param(
    [Parameter(Mandatory = $true)][string]$DataProductId,
    [Parameter(Mandatory = $true)][string[]]$AtlasAssetGuids
  )

  $allAssets = (Invoke-RestMethod -Uri "$dgBase/dataAssets?$apiUc&top=5000" -Headers $headers -Method Get).value
  $rels = (Invoke-RestMethod -Uri "$dgBase/dataproducts/$DataProductId/relationships?entityType=DataAsset&$apiUc" -Headers $headers -Method Get).value
  $existingIds = @($rels | ForEach-Object { $_.entityId })

  $linked = @()
  $missing = @()
  foreach ($atlasGuid in $AtlasAssetGuids) {
    $asset = $allAssets | Where-Object { [string]$_.source.assetId -eq $atlasGuid } | Select-Object -First 1
    if (-not $asset) {
      $missing += $atlasGuid
      continue
    }
    if ($existingIds -contains $asset.id) {
      $linked += "$($asset.name) (already linked)"
      continue
    }

    $body = @{ entityId = $asset.id; relationshipType = "Related" } | ConvertTo-Json -Compress
    $uri = "$dgBase/dataproducts/$DataProductId/relationships?entityType=DataAsset&$apiUc"
    $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
    if ($r.StatusCode -in 200, 201, 409) {
      $linked += "$($asset.name) (linked)"
    } else {
      $linked += "$($asset.name) (failed HTTP $($r.StatusCode))"
    }
  }

  return @{ linked = $linked; missing = $missing }
}

Write-Host "=== Full column lineage wiring: Finance Report <- Snowflake <- Salesforce ===" -ForegroundColor Cyan

$financeDatasetQn = "https://app.powerbi.com/groups/7000dcc5-3063-4dc7-99f5-965d551c2083/datasets/6b2e4d57-5492-4d99-85ec-1d23560b58a4"
$financeDatasetGuid = "0d401759-00e0-4dd7-a703-c65994568beb"
$financeTableQn = "$financeDatasetQn/tables/FinanceModel"

$salesforceObjectQn = @{
  Customer        = "https://ASIMPLEUPLOAD.salesforce.com/Customer"
  CustomerAddress = "https://ASIMPLEUPLOAD.salesforce.com/CustomerAdress"
  CustomerOutput  = "https://ASIMPLEUPLOAD.salesforce.com/Customer/Partition"
}

$snowflakeColumnQn = @{
  C_CUSTKEY     = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_CUSTKEY"
  C_NAME        = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_NAME"
  C_MKTSEGMENT  = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_MKTSEGMENT"
  C_ACCTBAL     = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_ACCTBAL"
  C_ADDRESS     = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_ADDRESS"
  C_PHONE       = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_PHONE"
  C_NATIONKEY   = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER/columns/C_NATIONKEY"
  O_ORDERKEY    = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/ORDERS/columns/O_ORDERKEY"
  O_ORDERDATE   = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/ORDERS/columns/O_ORDERDATE"
  O_TOTALPRICE  = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/ORDERS/columns/O_TOTALPRICE"
  O_ORDERSTATUS = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/ORDERS/columns/O_ORDERSTATUS"
  L_EXTENDEDPRICE = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/LINEITEM/columns/L_EXTENDEDPRICE"
  L_DISCOUNT    = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/LINEITEM/columns/L_DISCOUNT"
  L_SHIPDATE    = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/LINEITEM/columns/L_SHIPDATE"
}

$snowflakeColumnGuid = @{
  C_CUSTKEY      = "183cdb2a-dd72-497f-8a10-44f6f6f60006"
  C_NAME         = "183cdb2a-dd72-497f-8a10-44f6f6f60008"
  C_MKTSEGMENT   = "183cdb2a-dd72-497f-8a10-44f6f6f60002"
  C_ACCTBAL      = "183cdb2a-dd72-497f-8a10-44f6f6f60003"
  C_ADDRESS      = "183cdb2a-dd72-497f-8a10-44f6f6f60007"
  C_PHONE        = "183cdb2a-dd72-497f-8a10-44f6f6f60004"
  C_NATIONKEY    = "183cdb2a-dd72-497f-8a10-44f6f6f60005"
  O_ORDERKEY     = "040af482-eef1-477a-9f8d-f5f6f6f60002"
  O_ORDERDATE    = "040af482-eef1-477a-9f8d-f5f6f6f60004"
  O_TOTALPRICE   = "040af482-eef1-477a-9f8d-f5f6f6f60009"
  O_ORDERSTATUS  = "040af482-eef1-477a-9f8d-f5f6f6f60007"
  L_EXTENDEDPRICE = "bf8d0719-0ba5-45d9-a96c-1df6f6f60008"
  L_DISCOUNT     = "bf8d0719-0ba5-45d9-a96c-1df6f6f60007"
  L_SHIPDATE     = "bf8d0719-0ba5-45d9-a96c-1df6f6f60005"
}

$salesforceFields = @(
  @{ objectQn = $salesforceObjectQn.Customer;        field = "CUSTOMER_ID" },
  @{ objectQn = $salesforceObjectQn.Customer;        field = "CUSTOMER_NAME" },
  @{ objectQn = $salesforceObjectQn.Customer;        field = "CUSTOMER_SEGMENT" },
  @{ objectQn = $salesforceObjectQn.Customer;        field = "CUSTOMER_BALANCE" },
  @{ objectQn = $salesforceObjectQn.Customer;        field = "CUSTOMER_PHONE" },
  @{ objectQn = $salesforceObjectQn.CustomerAddress; field = "CUSTOMER_ADDRESS" },
  @{ objectQn = $salesforceObjectQn.CustomerAddress; field = "NATION_KEY" },
  @{ objectQn = $salesforceObjectQn.CustomerOutput;  field = "ORDER_ID" },
  @{ objectQn = $salesforceObjectQn.CustomerOutput;  field = "ORDER_STATUS" }
)

$financeColumns = @(
  "CUSTOMER_ID",
  "CUSTOMER_NAME",
  "CUSTOMER_SEGMENT",
  "ORDER_ID",
  "ORDER_DATE",
  "TOTAL_REVENUE",
  "NET_REVENUE",
  "DISCOUNT_AMOUNT",
  "SHIP_DATE",
  "ORDER_STATUS"
)

Write-Host "\n1) Ensuring report-side Power BI table and columns" -ForegroundColor Cyan
$null = Ensure-AtlasEntity -TypeName "powerbi_table" -QualifiedName $financeTableQn -Name "FinanceModel" -RelationshipAttributes @{
  dataset = @{ typeName = "powerbi_dataset"; uniqueAttributes = @{ qualifiedName = $financeDatasetQn } }
}

$powerbiColumns = @{}
foreach ($col in $financeColumns) {
  $qn = "$financeTableQn/columns/$col"
  $cg = Ensure-AtlasEntity -TypeName "powerbi_column" -QualifiedName $qn -Name $col -RelationshipAttributes @{
    table = @{ typeName = "powerbi_table"; uniqueAttributes = @{ qualifiedName = $financeTableQn } }
  }
  $powerbiColumns[$col] = @{ qn = $qn; guid = $cg }
}

Write-Host "2) Ensuring Salesforce field entities" -ForegroundColor Cyan
$salesforceFieldsMap = @{}
foreach ($sf in $salesforceFields) {
  $fq = "$($sf.objectQn)/fields/$($sf.field)"
  $fg = Ensure-AtlasEntity -TypeName "salesforce_field" -QualifiedName $fq -Name $sf.field -RelationshipAttributes @{
    object = @{ typeName = "salesforce_object"; uniqueAttributes = @{ qualifiedName = $sf.objectQn } }
  }
  $salesforceFieldsMap[$sf.field] = @{ qn = $fq; guid = $fg }
}

Write-Host "3) Creating Salesforce -> Snowflake column lineage" -ForegroundColor Cyan
$mapSfToSnow = @(
  @{ sf = "CUSTOMER_ID";      snow = "C_CUSTKEY" },
  @{ sf = "CUSTOMER_NAME";    snow = "C_NAME" },
  @{ sf = "CUSTOMER_SEGMENT"; snow = "C_MKTSEGMENT" },
  @{ sf = "CUSTOMER_BALANCE"; snow = "C_ACCTBAL" },
  @{ sf = "CUSTOMER_ADDRESS"; snow = "C_ADDRESS" },
  @{ sf = "CUSTOMER_PHONE";   snow = "C_PHONE" },
  @{ sf = "NATION_KEY";       snow = "C_NATIONKEY" },
  @{ sf = "ORDER_ID";         snow = "O_ORDERKEY" },
  @{ sf = "ORDER_STATUS";     snow = "O_ORDERSTATUS" }
)

$procCreated = @()
$processRegistry = @()
foreach ($m in $mapSfToSnow) {
  $pqn = "lineage://finance_path/salesforce_to_snowflake/$($m.sf.ToLower())"
  $pname = "LMAP_SF_TO_SNOW_$($m.sf)"
  $guid = Ensure-ProcessLineage -ProcessQualifiedName $pqn -ProcessName $pname -InputType "salesforce_field" -InputQualifiedName $salesforceFieldsMap[$m.sf].qn -InputGuid $salesforceFieldsMap[$m.sf].guid -OutputType "snowflake_table_column" -OutputQualifiedName $snowflakeColumnQn[$m.snow] -OutputGuid $snowflakeColumnGuid[$m.snow]
  $procCreated += "$pname [$guid]"
  $processRegistry += [pscustomobject]@{ hop = "salesforce_to_snowflake"; qn = $pqn; name = $pname; guid = $guid }
}

Write-Host "4) Creating Snowflake -> Finance Report column lineage" -ForegroundColor Cyan
$mapSnowToPbi = @(
  @{ snow = "C_CUSTKEY";      pbi = "CUSTOMER_ID" },
  @{ snow = "C_NAME";         pbi = "CUSTOMER_NAME" },
  @{ snow = "C_MKTSEGMENT";   pbi = "CUSTOMER_SEGMENT" },
  @{ snow = "O_ORDERKEY";     pbi = "ORDER_ID" },
  @{ snow = "O_ORDERDATE";    pbi = "ORDER_DATE" },
  @{ snow = "O_TOTALPRICE";   pbi = "TOTAL_REVENUE" },
  @{ snow = "L_EXTENDEDPRICE";pbi = "NET_REVENUE" },
  @{ snow = "L_DISCOUNT";     pbi = "DISCOUNT_AMOUNT" },
  @{ snow = "L_SHIPDATE";     pbi = "SHIP_DATE" },
  @{ snow = "O_ORDERSTATUS";  pbi = "ORDER_STATUS" }
)

foreach ($m in $mapSnowToPbi) {
  $pqn = "lineage://finance_path/snowflake_to_finance_report/$($m.pbi.ToLower())"
  $pname = "LMAP_SNOW_TO_PBI_$($m.pbi)"
  $guid = Ensure-ProcessLineage -ProcessQualifiedName $pqn -ProcessName $pname -InputType "snowflake_table_column" -InputQualifiedName $snowflakeColumnQn[$m.snow] -InputGuid $snowflakeColumnGuid[$m.snow] -OutputType "powerbi_column" -OutputQualifiedName $powerbiColumns[$m.pbi].qn -OutputGuid $powerbiColumns[$m.pbi].guid
  $procCreated += "$pname [$guid]"
  $processRegistry += [pscustomobject]@{ hop = "snowflake_to_powerbi"; qn = $pqn; name = $pname; guid = $guid }
}

Write-Host "5) Ensuring DataAsset attachments on Executive Financial Dashboards" -ForegroundColor Cyan
$dpExecutiveFinancial = "4baeadc4-224c-43be-93a5-819ed2fb9e97"
$attachResult = Ensure-DataProductAssetLinks -DataProductId $dpExecutiveFinancial -AtlasAssetGuids @(
  "0d401759-00e0-4dd7-a703-c65994568beb", # Finance Report dataset
  "ff85faf3-8863-479e-a443-bf5f6f6f6000", # CUSTOMER table
  "040af482-eef1-477a-9f8d-f5f6f6f60000", # ORDERS table
  "bf8d0719-0ba5-45d9-a96c-1df6f6f60000", # LINEITEM table
  "eea7dfee-89a1-43fc-ab83-9cf6f6f60000", # Salesforce Customer data
  "8d02c8fe-d541-4b95-bcb0-0cf6f6f60000", # Salesforce Customer Address data
  "70818ae9-5e85-4fd2-90cb-a9f6f6f60000"  # Customer salesforce output
)

Write-Host "6) Verifying each generated process and hop-level lineage" -ForegroundColor Cyan
$verificationRows = @()
foreach ($p in $processRegistry) {
  $procGuid = [string]$p.guid
  if (-not $procGuid) {
    $verificationRows += [ordered]@{
      process = $p.name
      hop = $p.hop
      processGuid = $procGuid
      status = "missing"
      inputType = $null
      inputName = $null
      outputType = $null
      outputName = $null
      lineageEntityCountFromProcess = 0
    }
    continue
  }

  $procEntityUri = "$atlasBase/entity/guid/${procGuid}?api-version=2022-03-01-preview&minExtInfo=false&ignoreRelationships=false"
  try {
    $procEntity = (Invoke-RestMethod -Uri $procEntityUri -Headers $headers -Method Get).entity
  } catch {
    $verificationRows += [ordered]@{
      process = $p.name
      hop = $p.hop
      processGuid = $procGuid
      status = "missing"
      inputType = $null
      inputName = $null
      outputType = $null
      outputName = $null
      lineageEntityCountFromProcess = 0
    }
    continue
  }

  $inRel = @($procEntity.relationshipAttributes.inputs | Select-Object -First 1)
  $outRel = @($procEntity.relationshipAttributes.outputs | Select-Object -First 1)

  $lineageCount = 0
  try {
    $procLineageUri = "$atlasBase/lineage/${procGuid}?direction=BOTH&depth=20&api-version=2022-03-01-preview"
    $procLineage = Invoke-RestMethod -Uri $procLineageUri -Headers $headers -Method Get
    $lineageCount = @($procLineage.guidEntityMap.PSObject.Properties).Count
  } catch {
    $lineageCount = 0
  }

  $verificationRows += [ordered]@{
    process = $p.name
    hop = $p.hop
    processGuid = $procGuid
    status = "ok"
    inputType = if ($inRel.Count -gt 0) { [string]$inRel[0].typeName } else { $null }
    inputName = if ($inRel.Count -gt 0) { [string]$inRel[0].displayText } else { $null }
    outputType = if ($outRel.Count -gt 0) { [string]$outRel[0].typeName } else { $null }
    outputName = if ($outRel.Count -gt 0) { [string]$outRel[0].displayText } else { $null }
    lineageEntityCountFromProcess = $lineageCount
  }
}

$okProcesses = @($verificationRows | Where-Object { $_.status -eq "ok" }).Count
$sfHopOk = @($verificationRows | Where-Object { $_.hop -eq "salesforce_to_snowflake" -and $_.status -eq "ok" }).Count
$pbiHopOk = @($verificationRows | Where-Object { $_.hop -eq "snowflake_to_powerbi" -and $_.status -eq "ok" }).Count

$report = [ordered]@{
  generatedAtUtc = [DateTime]::UtcNow.ToString("s") + "Z"
  scope = "Finance Report <- Snowflake <- Salesforce (column lineage)"
  financeDatasetGuid = $financeDatasetGuid
  powerbiTableQualifiedName = $financeTableQn
  mappings = [ordered]@{
    salesforceToSnowflake = $mapSfToSnow
    snowflakeToPowerBI = $mapSnowToPbi
  }
  verification = [ordered]@{
    expectedProcesses = $processRegistry.Count
    verifiedProcesses = $okProcesses
    verifiedSalesforceToSnowflake = $sfHopOk
    verifiedSnowflakeToPowerBI = $pbiHopOk
  }
  processVerificationRows = $verificationRows
  dataProductAssetLinking = [ordered]@{
    dataProductId = $dpExecutiveFinancial
    linkedOrExisting = $attachResult.linked
    missingDataAssetForAtlasGuid = $attachResult.missing
  }
  createdOrExistingProcesses = $procCreated
}

$jsonPath = ".\\docs\\lineage_finance_snowflake_salesforce_columns.json"
$mdPath = ".\\docs\\lineage_finance_snowflake_salesforce_columns.md"

$report | ConvertTo-Json -Depth 30 | Out-File -FilePath $jsonPath -Encoding utf8

$md = @()
$md += "# Finance Report Column Lineage: Snowflake and Salesforce"
$md += ""
$md += "Generated (UTC): $($report.generatedAtUtc)"
$md += ""
$md += "## Scope"
$md += "- Finance Report dataset GUID: $financeDatasetGuid"
$md += "- Path: Salesforce fields -> Snowflake columns -> Finance Report Power BI columns"
$md += ""
$md += "## Verification Summary"
$md += "- Expected process mappings: $($processRegistry.Count)"
$md += "- Verified process entities: $okProcesses"
$md += "- Verified Salesforce -> Snowflake mappings: $sfHopOk"
$md += "- Verified Snowflake -> Power BI mappings: $pbiHopOk"
$md += ""
$md += "## Process Verification (input -> output)"
foreach ($v in $verificationRows) {
  $md += "- [$($v.hop)] $($v.process): $($v.inputType) '$($v.inputName)' -> $($v.outputType) '$($v.outputName)' (status=$($v.status), lineageEntitiesFromProcess=$($v.lineageEntityCountFromProcess))"
}
$md += ""
$md += "## Salesforce -> Snowflake Column Mappings"
foreach ($m in $mapSfToSnow) {
  $md += "- $($m.sf) -> $($m.snow)"
}
$md += ""
$md += "## Snowflake -> Finance Report Column Mappings"
foreach ($m in $mapSnowToPbi) {
  $md += "- $($m.snow) -> $($m.pbi)"
}
$md += ""
$md += "## Data Product Asset Attachment Check"
$md += "- Data Product ID: $dpExecutiveFinancial"
foreach ($l in $attachResult.linked) {
  $md += "- $l"
}
if ($attachResult.missing.Count -gt 0) {
  $md += ""
  $md += "Missing DataAsset records for Atlas GUIDs:"
  foreach ($g in $attachResult.missing) {
    $md += "- $g"
  }
}

$md -join "`r`n" | Out-File -FilePath $mdPath -Encoding utf8

Write-Host "\n=== Completed ===" -ForegroundColor Green
Write-Host "JSON report: $jsonPath"
Write-Host "Markdown report: $mdPath"
Write-Host "Verified process mappings: $okProcesses / $($processRegistry.Count)"
