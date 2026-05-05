$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Get governance entities from catalog search
$body = '{"keywords":"*","filter":{"or":[{"entityType":"Purview_ApplicationService"},{"entityType":"Purview_Product"},{"entityType":"Digital Product TDF"}]},"limit":50}'
$r = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $body

Write-Host "Found $($r.'@search.count') governance entities" -ForegroundColor Green

$allDetails = @()
foreach ($e in $r.value) {
    try {
        $detail = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/entity/guid/$($e.id)?api-version=2022-03-01-preview" -Headers $headers
        $allDetails += $detail
        $ent = $detail.entity
        Write-Host "`n=== $($ent.typeName): $($ent.attributes.name) ===" -ForegroundColor Cyan
        Write-Host "  GUID: $($ent.guid)"
        Write-Host "  Status: $($ent.status)"
        Write-Host "  Description: $($ent.attributes.description)"
        Write-Host "  Owner: $($ent.attributes.owner)"
        
        # All custom attributes
        $ent.attributes.PSObject.Properties | ForEach-Object { 
            if ($_.Value -and $_.Name -notin @("name","description","qualifiedName","owner","replicatedTo","replicatedFrom","userDescription")) {
                Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor DarkYellow
            }
        }
        
        # Relationships
        if ($ent.relationshipAttributes) {
            $ent.relationshipAttributes.PSObject.Properties | ForEach-Object {
                if ($_.Value) {
                    $relVal = $_.Value
                    if ($relVal -is [array] -and $relVal.Count -gt 0) {
                        Write-Host "  Rel/$($_.Name): $($relVal.Count) items" -ForegroundColor Magenta
                        $relVal | ForEach-Object { Write-Host "    -> $($_.displayText) [$($_.typeName)]" }
                    } elseif ($relVal -isnot [array]) {
                        Write-Host "  Rel/$($_.Name): $($relVal.displayText) [$($relVal.typeName)]" -ForegroundColor Magenta
                    }
                }
            }
        }
        
        # Classifications
        if ($ent.classifications) {
            Write-Host "  Classifications:" -ForegroundColor Yellow
            $ent.classifications | ForEach-Object { Write-Host "    - $($_.typeName)" }
        }
    } catch { 
        Write-Host "  Error for $($e.name): $($_.Exception.Message)" -ForegroundColor Red 
    }
}

# Also get the Purview_ApplicationService and Purview_Product type definitions
Write-Host "`n`n=== TYPE DEFINITIONS ===" -ForegroundColor Cyan
foreach ($typeName in @("Purview_ApplicationService", "Purview_Product", "Digital Product TDF")) {
    try {
        $typeDef = Invoke-RestMethod -Uri "$baseUrl/catalog/api/atlas/v2/types/typedef/name/$typeName`?api-version=2022-03-01-preview" -Headers $headers
        Write-Host "`nType: $($typeDef.name) [Category: $($typeDef.category)]" -ForegroundColor Yellow
        Write-Host "  Description: $($typeDef.description)"
        Write-Host "  Service Type: $($typeDef.serviceType)"
        Write-Host "  Attributes:" -ForegroundColor DarkYellow
        $typeDef.attributeDefs | ForEach-Object { Write-Host "    - $($_.name) [$($_.typeName)] $($_.isOptional ? 'optional' : 'required')" }
        if ($typeDef.relationshipAttributeDefs) {
            Write-Host "  Relationship Attributes:" -ForegroundColor Magenta
            $typeDef.relationshipAttributeDefs | ForEach-Object { Write-Host "    - $($_.name) [$($_.typeName)] -> $($_.relationshipTypeName)" }
        }
    } catch { Write-Host "  Error getting typedef $typeName" -ForegroundColor Red }
}

# Also search for SAP application service entities
Write-Host "`n`n=== SAP APPLICATION SERVICES ===" -ForegroundColor Cyan
$sapBody = '{"keywords":"*","filter":{"entityType":"SAP application service"},"limit":20}'
try {
    $sap = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $sapBody
    Write-Host "Found: $($sap.'@search.count') SAP application services"
    $sap.value | ForEach-Object { Write-Host "  - $($_.name) [Collection: $($_.collectionId)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# Search for any Process entities (lineage)
Write-Host "`n=== PROCESS ENTITIES (LINEAGE) ===" -ForegroundColor Cyan
$procBody = '{"keywords":"*","filter":{"or":[{"entityType":"Process"},{"entityType":"ProcessCustomSnowflake"},{"entityType":"SnowflakeStageProcess"}]},"limit":30}'
try {
    $procs = Invoke-RestMethod -Uri "$baseUrl/catalog/api/search/query?api-version=2022-08-01-preview" -Headers $headers -Method Post -Body $procBody
    Write-Host "Found: $($procs.'@search.count') process/lineage entities"
    $procs.value | ForEach-Object { Write-Host "  - $($_.name) [Type: $($_.entityType)] [Collection: $($_.collectionId)]" }
} catch { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }

# Export details
$allDetails | ConvertTo-Json -Depth 10 | Out-File "c:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview\governance_entities_detail.json" -Encoding utf8
Write-Host "`n=== EXPORTED ===" -ForegroundColor Green
