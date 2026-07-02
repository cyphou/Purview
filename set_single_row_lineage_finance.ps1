param(
  [string]$PurviewAccount = "pdedemopurv",
  [switch]$DeleteColumnLevelMappings = $true
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$atlasBase = "$base/catalog/api/atlas/v2"
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

function Resolve-AtlasGuid {
  param(
    [Parameter(Mandatory = $true)][string]$TypeName,
    [Parameter(Mandatory = $true)][string]$QualifiedName
  )

  $ent = Get-AtlasByQualifiedName -TypeName $TypeName -QualifiedName $QualifiedName
  if ($ent) { return [string]$ent.guid }

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

function Ensure-CompositeProcessLineage {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessQualifiedName,
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][array]$Inputs,
    [Parameter(Mandatory = $true)][array]$Outputs,
    [string]$Description
  )

  $existing = Get-AtlasByQualifiedName -TypeName "Process" -QualifiedName $ProcessQualifiedName
  if ($existing) {
    return [string]$existing.guid
  }

  $inputRefs = @()
  foreach ($i in $Inputs) {
    $g = if ($i.guid) { [string]$i.guid } else { Resolve-AtlasGuid -TypeName $i.type -QualifiedName $i.qn }
    if (-not $g) { throw "Input entity not found: $($i.type) :: $($i.qn)" }
    $inputRefs += @{ typeName = $i.type; guid = $g }
  }

  $outputRefs = @()
  foreach ($o in $Outputs) {
    $g = if ($o.guid) { [string]$o.guid } else { Resolve-AtlasGuid -TypeName $o.type -QualifiedName $o.qn }
    if (-not $g) { throw "Output entity not found: $($o.type) :: $($o.qn)" }
    $outputRefs += @{ typeName = $o.type; guid = $g }
  }

  $mappings = @()
  foreach ($i in $Inputs) {
    foreach ($o in $Outputs) {
      $mappings += @{
        Source = @{ name = $i.qn; type = $i.type }
        Sink = @{ name = $o.qn; type = $o.type }
      }
    }
  }

  $attrs = @{
    qualifiedName = $ProcessQualifiedName
    name = $ProcessName
    inputs = $inputRefs
    outputs = $outputRefs
    columnMapping = ($mappings | ConvertTo-Json -Depth 12 -Compress)
  }
  if ($Description) {
    $attrs["description"] = $Description
    $attrs["userDescription"] = $Description
  }

  $body = @{ entity = @{ typeName = "Process"; attributes = $attrs } } | ConvertTo-Json -Depth 30
  $r = Invoke-WebRequest -Uri "$atlasBase/entity" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
  $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
  if ($r.StatusCode -notin 200, 201) {
    throw "Failed to create process '$ProcessName'. HTTP $($r.StatusCode) :: $($content.Substring(0, [Math]::Min(500, $content.Length)))"
  }

  $parsed = $content | ConvertFrom-Json
  $createdEntities = @($parsed.mutatedEntities.CREATE)
  if ($createdEntities.Count -gt 0 -and $createdEntities[0].guid) {
    return [string]$createdEntities[0].guid
  }

  $updatedEntities = @($parsed.mutatedEntities.UPDATE)
  if ($updatedEntities.Count -gt 0 -and $updatedEntities[0].guid) {
    return [string]$updatedEntities[0].guid
  }

  if ($parsed.guidAssignments) {
    $assignment = $parsed.guidAssignments.PSObject.Properties | Select-Object -First 1
    if ($assignment -and $assignment.Value) {
      return [string]$assignment.Value
    }
  }

  $created = Get-AtlasByQualifiedName -TypeName "Process" -QualifiedName $ProcessQualifiedName
  if ($created) {
    return [string]$created.guid
  }

  throw "Process created but no guid could be resolved: $ProcessQualifiedName"
}

function Delete-ProcessByGuid {
  param([Parameter(Mandatory = $true)][string]$Guid)

  $uri = "$atlasBase/entity/guid/$Guid"
  $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Delete -SkipHttpErrorCheck
  return $r.StatusCode
}

Write-Host "=== Consolidating to single-row lineage: Salesforce -> Snowflake -> PowerBI ===" -ForegroundColor Cyan

$financeDataset = @{
  type = "powerbi_dataset"
  qn = "https://app.powerbi.com/groups/7000dcc5-3063-4dc7-99f5-965d551c2083/datasets/6b2e4d57-5492-4d99-85ec-1d23560b58a4"
  guid = "0d401759-00e0-4dd7-a703-c65994568beb"
}

$salesforceInputs = @(
  @{ type = "salesforce_object"; qn = "https://ASIMPLEUPLOAD.salesforce.com/Customer" }
)

$snowflakeInputs = @(
  @{ type = "snowflake_table"; qn = "snowflake://https/databases/SNOWFLAKE_SAMPLE_DATA/schemas/TPCH_SF1/tables/CUSTOMER"; guid = "183cdb2a-dd72-497f-8a10-44f6f6f60000" }
)

if ($DeleteColumnLevelMappings) {
  Write-Host "1) Deleting old column-level LMAP processes" -ForegroundColor Cyan
  $query = @{
    keywords = "lineage://finance_path/"
    limit = 200
    filter = @{ entityType = "Process" }
  } | ConvertTo-Json -Depth 8

  $search = Invoke-RestMethod -Uri "$base/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $query
  $toDelete = @($search.value | Where-Object { [string]$_.qualifiedName -like "lineage://finance_path/*" })

  foreach ($p in $toDelete) {
    $status = Delete-ProcessByGuid -Guid ([string]$p.id)
    Write-Host "  Deleted $($p.name) [$($p.id)] (HTTP $status)"
  }
}

Write-Host "2) Creating one Salesforce -> Snowflake process" -ForegroundColor Cyan
$sfToSnowGuid = Ensure-CompositeProcessLineage `
  -ProcessQualifiedName "lineage://finance_path/salesforce_to_snowflake/single_row" `
  -ProcessName "LMAP_SF_TO_SNOW_SINGLE" `
  -Inputs $salesforceInputs `
  -Outputs $snowflakeInputs `
  -Description "Single-row hop from Salesforce Customer object to Snowflake CUSTOMER table."

Write-Host "3) Creating one Snowflake -> PowerBI process" -ForegroundColor Cyan
$snowToPbiGuid = Ensure-CompositeProcessLineage `
  -ProcessQualifiedName "lineage://finance_path/snowflake_to_powerbi/single_row" `
  -ProcessName "LMAP_SNOW_TO_PBI_SINGLE" `
  -Inputs $snowflakeInputs `
  -Outputs @($financeDataset) `
  -Description "Single-row hop from Snowflake CUSTOMER table to Finance Report Power BI dataset."

Write-Host "4) Verifying consolidated process count" -ForegroundColor Cyan
$verifyQuery = @{
  keywords = "lineage://finance_path/"
  limit = 200
  filter = @{ entityType = "Process" }
} | ConvertTo-Json -Depth 8
$verify = Invoke-RestMethod -Uri "$base/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $verifyQuery
$financeProcesses = @($verify.value | Where-Object { [string]$_.qualifiedName -like "lineage://finance_path/*" } | Sort-Object name)

$result = [ordered]@{
  generatedAtUtc = [DateTime]::UtcNow.ToString("s") + "Z"
  singleSalesforceToSnowflakeProcessGuid = $sfToSnowGuid
  singleSnowflakeToPowerBIProcessGuid = $snowToPbiGuid
  totalFinancePathProcesses = $financeProcesses.Count
  processes = @($financeProcesses | ForEach-Object {
      [ordered]@{
        name = [string]$_.name
        guid = [string]$_.id
        qualifiedName = [string]$_.qualifiedName
      }
    })
}

$outJson = ".\\docs\\lineage_finance_single_row_status.json"
$result | ConvertTo-Json -Depth 8 | Out-File -FilePath $outJson -Encoding utf8

Write-Host "\n=== Completed ===" -ForegroundColor Green
Write-Host "Consolidated process GUIDs:"
Write-Host "- Salesforce -> Snowflake: $sfToSnowGuid"
Write-Host "- Snowflake -> PowerBI: $snowToPbiGuid"
Write-Host "Total finance_path processes now: $($financeProcesses.Count)"
Write-Host "Verification JSON: $outJson"
