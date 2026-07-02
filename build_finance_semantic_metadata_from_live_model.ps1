param(
  [string]$OutPath = '.\\docs\\finance_report_semantic_metadata.json'
)

$ErrorActionPreference = 'Stop'

$tablesJson = @'
{
  "data": [
    {"tableName":"DateTableTemplate_65c10c54-0d8a-4700-89d5-02d5c0cd375c","columns":[{"dataType":"DateTime","name":"Date"},{"dataType":"Int64","isCalculated":true,"name":"Year"},{"dataType":"Int64","isCalculated":true,"name":"MonthNo"},{"dataType":"String","isCalculated":true,"name":"Month"},{"dataType":"Int64","isCalculated":true,"name":"QuarterNo"},{"dataType":"String","isCalculated":true,"name":"Quarter"},{"dataType":"Int64","isCalculated":true,"name":"Day"}]},
    {"tableName":"ConflictofInterest","columns":[{"dataType":"String","name":"FiscalYear-Quarter"},{"dataType":"String","name":"Fiscal Year"},{"dataType":"String","name":"Fiscal Quarter"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Region"},{"dataType":"Int64","name":"Required"},{"dataType":"Int64","name":"Complete"},{"dataType":"Int64","name":"Survey NC"},{"dataType":"Int64","name":"Incomplete"},{"dataType":"String","name":"Function Summary"},{"dataType":"Int64","name":"Complete %"}]},
    {"tableName":"Country","columns":[{"dataType":"Int64","name":"ID"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Region"}]},
    {"tableName":"FP&A","columns":[{"dataType":"String","name":"Fiscal Year"},{"dataType":"String","name":"Fiscal Quarter"},{"dataType":"Int64","name":"Fiscal Month"},{"dataType":"String","name":"Country"},{"dataType":"Int64","name":"Forecast"},{"dataType":"Int64","name":"Budget"},{"dataType":"Double","name":"Actual"}]},
    {"tableName":"OperatingExpenses","columns":[{"dataType":"String","name":"Class"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Function Summary"},{"dataType":"String","name":"Line Item"},{"dataType":"String","name":"P&L Classification"},{"dataType":"Double","name":"VTB (%)"},{"dataType":"Decimal","name":"Actual ($)"},{"dataType":"Decimal","name":"Budget ($)"},{"dataType":"Decimal","name":"VTB ($)"},{"dataType":"Decimal","name":"YoY ($)"},{"dataType":"String","name":"Channel"},{"dataType":"String","name":"Region"}]},
    {"tableName":"Sales","columns":[{"dataType":"String","name":"Fiscal Year"},{"dataType":"String","name":"Fiscal Quarter"},{"dataType":"Int64","name":"Fiscal Month"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Region"},{"dataType":"String","name":"Customer Segment"},{"dataType":"String","name":"Product Line"},{"dataType":"String","name":"Product"},{"dataType":"String","name":"Product Category"},{"dataType":"Decimal","name":"Interest and Fee Income"},{"dataType":"Decimal","name":"Budget"},{"dataType":"Double","name":"Forecast"},{"dataType":"Decimal","name":"Discount"},{"dataType":"Decimal","name":"Net Sales"},{"dataType":"Decimal","name":"COGS"},{"dataType":"Decimal","name":"Gross Profit"},{"dataType":"String","name":"Half Yearly"},{"dataType":"Decimal","name":"VTB ($)"},{"dataType":"Decimal","name":"VTB (%)"}]},
    {"tableName":"SalesVsExpense","columns":[{"dataType":"String","name":"Accounting Head"},{"dataType":"Decimal","name":"Amount"}]},
    {"tableName":"SiteSecurity","columns":[{"dataType":"String","name":"FiscalQuarter"},{"dataType":"String","name":"FiscalYear"},{"dataType":"String","name":"FiscalMonth"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Region"},{"dataType":"String","name":"Phase"},{"dataType":"Int64","name":"Total Vulnerabilities"},{"dataType":"Int64","name":"Total Open Vulnerabilities"},{"dataType":"String","name":"Status"},{"dataType":"String","name":"Data Classification"},{"dataType":"Int64","name":"App Scan High Risk"},{"dataType":"Int64","name":"App Scan Low Risk"},{"dataType":"Int64","name":"Host Scan high Risk"},{"dataType":"Int64","name":"Host Scan Low Risk"},{"dataType":"Int64","name":"Active Sites Not Scanned"},{"dataType":"String","name":"Site Status"},{"dataType":"Int64","name":"Total Vuln"}]},
    {"tableName":"Travel&Entertainment","columns":[{"dataType":"DateTime","name":"Completion Date"},{"dataType":"String","name":"Month"},{"dataType":"String","name":"Audit Status"},{"dataType":"String","name":"Country"},{"dataType":"String","name":"Status Description"},{"dataType":"String","name":"Region"},{"dataType":"Int64","name":"Serious Failed"},{"dataType":"Int64","name":"Serious Failed Expenses"},{"dataType":"String","name":"Function Summary"}]},
    {"tableName":"VTB ($) by channel","columns":[{"dataType":"Decimal","name":"Amount"},{"dataType":"String","name":"VTB ($) by channel"}]},
    {"tableName":"LocalDateTable_b9f97684-05ee-47b3-bc25-548fc636a0d4","columns":[{"dataType":"DateTime","name":"Date"},{"dataType":"Int64","isCalculated":true,"name":"Year"},{"dataType":"Int64","isCalculated":true,"name":"MonthNo"},{"dataType":"String","isCalculated":true,"name":"Month"},{"dataType":"Int64","isCalculated":true,"name":"QuarterNo"},{"dataType":"String","isCalculated":true,"name":"Quarter"},{"dataType":"Int64","isCalculated":true,"name":"Day"}]}
  ]
}
'@

$measuresJson = @'
{
  "results": [
    {"success":true,"data":{"tableName":"Sales","name":"FVTB%","expression":"IF(SUM(Sales[Budget])>0,((Sum(Sales[Forecast])/Sum(Sales[Budget]))-1),0)","description":"","formatString":"0.00%;-0.00%;0.00%","displayFolder":"","isHidden":false}},
    {"success":true,"data":{"tableName":"Sales","name":"FVTB$","expression":"Sum(Sales[Forecast])-Sum(Sales[Budget])","description":"","formatString":"","displayFolder":"","isHidden":false}}
  ]
}
'@

$relationshipsJson = @'
{
  "data": [
    {"fromTable":"Travel&Entertainment","fromColumn":"Completion Date","toTable":"LocalDateTable_b9f97684-05ee-47b3-bc25-548fc636a0d4","toColumn":"Date","isActive":true,"crossFilteringBehavior":"OneDirection","name":"dccd854c-4514-42c8-9ecc-90c3cff1c883"},
    {"fromTable":"Sales","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":true,"crossFilteringBehavior":"BothDirections","name":"98caeffe-75e5-47bc-87a1-1ab21aa1ed54"},
    {"fromTable":"ConflictofInterest","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":true,"crossFilteringBehavior":"OneDirection","name":"5496df35-6da6-4cd0-89c8-217e7cf6d38b"},
    {"fromTable":"Travel&Entertainment","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":true,"crossFilteringBehavior":"OneDirection","name":"5a587f0a-b3cd-470b-9528-058387cf1fed"},
    {"fromTable":"SiteSecurity","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":true,"crossFilteringBehavior":"OneDirection","name":"d1e8b05b-2ccd-42a1-a574-2125ef5884a2"},
    {"fromTable":"OperatingExpenses","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":true,"crossFilteringBehavior":"OneDirection","name":"40b4f8f2-69bc-4d64-9c61-7dd03748266b"},
    {"fromTable":"ConflictofInterest","fromColumn":"Fiscal Year","toTable":"FP&A","toColumn":"Fiscal Year","isActive":true,"crossFilteringBehavior":"OneDirection","name":"55c40595-1e04-4a14-b24d-dacac893a376"},
    {"fromTable":"Sales","fromColumn":"Fiscal Year","toTable":"FP&A","toColumn":"Fiscal Year","isActive":true,"crossFilteringBehavior":"OneDirection","name":"11021585-7e47-435c-a5fb-24a1465be3bc"},
    {"fromTable":"SiteSecurity","fromColumn":"FiscalYear","toTable":"FP&A","toColumn":"Fiscal Year","isActive":true,"crossFilteringBehavior":"OneDirection","name":"1897e694-28ab-4817-b147-22cb9ac7bf2e"},
    {"fromTable":"FP&A","fromColumn":"Country","toTable":"Country","toColumn":"Country","isActive":false,"crossFilteringBehavior":"OneDirection","name":"f8ac957e-2e29-42e2-b5d3-02b966e66ecc"}
  ]
}
'@

$rolesJson = @'
[]
'@

$hierarchiesJson = @'
{
  "data": [
    {
      "tableName": "DateTableTemplate_65c10c54-0d8a-4700-89d5-02d5c0cd375c",
      "hierarchies": [
        {
          "name": "Date Hierarchy",
          "description": "",
          "levels": [
            {"name": "Year", "columnName": "Year"},
            {"name": "Quarter", "columnName": "Quarter"},
            {"name": "Month", "columnName": "Month"},
            {"name": "Day", "columnName": "Day"}
          ]
        }
      ]
    }
  ]
}
'@

$tablesData = $tablesJson | ConvertFrom-Json
$measuresData = $measuresJson | ConvertFrom-Json
$relationshipsData = $relationshipsJson | ConvertFrom-Json
$rolesData = $rolesJson | ConvertFrom-Json
$hierarchiesData = $hierarchiesJson | ConvertFrom-Json

$rolesOut = @()
if ($rolesData) {
  if ($rolesData.PSObject.Properties.Name -contains 'data') {
    $rolesOut = @($rolesData.data)
  } else {
    $rolesOut = @($rolesData)
  }
}

$hierarchiesByTable = @{}
foreach ($entry in @($hierarchiesData.data)) {
  $hierarchiesByTable[$entry.tableName] = @($entry.hierarchies)
}

$tablesOut = @()
foreach ($entry in @($tablesData.data)) {
  $tableName = [string]$entry.tableName
  $columnsOut = @()
  foreach ($col in @($entry.columns)) {
    $calcSuffix = if ($col.isCalculated) { '; Calculated=true' } else { '' }
    $columnsOut += [ordered]@{
      name = [string]$col.name
      description = "Live semantic model column from Finance Report. DataType=$($col.dataType)$calcSuffix"
      dataType = [string]$col.dataType
      isHidden = $false
      formatString = ''
    }
  }

  $tableHierarchies = @()
  if ($hierarchiesByTable.ContainsKey($tableName)) {
    foreach ($h in @($hierarchiesByTable[$tableName])) {
      $levels = @()
      foreach ($lvl in @($h.levels)) {
        $levels += [ordered]@{
          name = [string]$lvl.name
          column = [string]$lvl.columnName
        }
      }
      $tableHierarchies += [ordered]@{
        name = [string]$h.name
        description = [string]$h.description
        levels = $levels
      }
    }
  }

  $tablesOut += [ordered]@{
    name = $tableName
    description = "Live semantic model table from Finance Report with $(@($entry.columns).Count) columns."
    isHidden = $false
    columns = $columnsOut
    hierarchies = $tableHierarchies
  }
}

$measuresOut = @()
foreach ($item in @($measuresData.results)) {
  if (-not $item.success) { continue }
  $m = $item.data
  $measuresOut += [ordered]@{
    table = [string]$m.tableName
    name = [string]$m.name
    description = [string]$m.description
    expression = [string]$m.expression
    formatString = [string]$m.formatString
    displayFolder = [string]$m.displayFolder
    isHidden = [bool]$m.isHidden
  }
}

$relationshipsOut = @()
foreach ($r in @($relationshipsData.data)) {
  $relationshipsOut += [ordered]@{
    name = [string]$r.name
    description = ''
    fromTable = [string]$r.fromTable
    fromColumn = [string]$r.fromColumn
    toTable = [string]$r.toTable
    toColumn = [string]$r.toColumn
    crossFilteringBehavior = [string]$r.crossFilteringBehavior
    isActive = [bool]$r.isActive
  }
}

$payload = [ordered]@{
  source = 'live-fabric-semantic-model'
  generatedAtUtc = [DateTime]::UtcNow.ToString('o')
  workspace = 'DDiB-FSI'
  dataset = 'Finance Report'
  tables = $tablesOut
  measures = $measuresOut
  relationships = $relationshipsOut
  roles = $rolesOut
}

$payload | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutPath -Encoding utf8
Write-Host "Wrote semantic metadata JSON to $OutPath"
Write-Host "Tables: $($tablesOut.Count) Measures: $($measuresOut.Count) Relationships: $($relationshipsOut.Count) Roles: $($rolesOut.Count)"
