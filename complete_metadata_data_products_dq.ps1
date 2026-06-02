# Complete metadata for Data Products + attach Data Assets/Terms + apply Data Quality via API
#
# What this script does (idempotent as much as possible):
# 1) Creates or updates a "Data Quality" custom metadata group.
# 2) Ensures Atlas classification typedefs exist: DQ_Gold / DQ_Silver / DQ_Bronze.
# 3) For each curated Data Product:
#    - attaches matching Data Assets
#    - attaches matching Terms
# 4) Applies DQ classification on the underlying Atlas assets used by Data Products.

$ErrorActionPreference = "Continue"

$base = "https://pdedemopurv.purview.azure.com"
$dgBase = "$base/datagovernance/catalog"
$atlasBase = "$base/catalog/api/atlas/v2"
$api = "?api-version=2026-03-20-preview"

if (-not $token) {
    $token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
}

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Read-TextContent($webResponse) {
    if ($null -eq $webResponse) { return "" }
    if ($webResponse.Content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($webResponse.Content)
    }
    return [string]$webResponse.Content
}

function Set-DqCustomMetadataGroup {
    Write-Host "`n=== Ensure Data Quality custom metadata group ===" -ForegroundColor Cyan

    $all = Invoke-RestMethod -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Get
    $existing = $all.value | Where-Object { $_.name -eq "Data Quality" }

    $bodyObj = @{
        name = "Data Quality"
        type = "BusinessConcept"
        status = "Published"
        description = "Data Quality governance fields for demo usage on Data Products."
        scope = @{
            applicableConstructs = @{
                domains = @{ includesAll = $true; includes = @() }
                businessConcepts = @{ includesAll = $false; includes = @("DataProduct") }
                dataProductTypes = @{ includesAll = $true; includes = @() }
            }
        }
        attributes = @(
            @{ type="string"; status="Published"; name="Quality Score (0-100)"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Quality Tier"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Last Scan Date"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Active Rules"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
        )
    }
    if ($existing) {
        $bodyObj.id = $existing.id
        $body = $bodyObj | ConvertTo-Json -Depth 10
        $r = Invoke-WebRequest -Uri "$dgBase/customMetadata/$($existing.id)$api" -Headers $headers -Method Put -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -eq 200) {
            Write-Host "  updated: Data Quality ($($existing.id))" -ForegroundColor Green
        } elseif ($r.StatusCode -eq 400) {
            Write-Host "  keep existing: Data Quality ($($existing.id)) (immutable fields rejected by API)" -ForegroundColor DarkYellow
        } else {
            Write-Host "  warn: update Data Quality -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
        }
    } else {
        $body = $bodyObj | ConvertTo-Json -Depth 10
        $r = Invoke-WebRequest -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -in 200, 201) {
            $obj = (Read-TextContent $r) | ConvertFrom-Json
            Write-Host "  created: Data Quality ($($obj.id))" -ForegroundColor Green
        } else {
            Write-Host "  warn: create Data Quality -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
        }
    }
}

function Set-SnowflakeCustomMetadataGroup {
    Write-Host "`n=== Ensure Snowflake Source custom metadata group ===" -ForegroundColor Cyan

    $all = Invoke-RestMethod -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Get
    $existing = $all.value | Where-Object { $_.name -eq "Snowflake Source Metadata" }

    $bodyObj = @{
        name = "Snowflake Source Metadata"
        type = "BusinessConcept"
        status = "Published"
        description = "Snowflake source descriptors to standardize metadata usage across all Data Products."
        scope = @{
            applicableConstructs = @{
                domains = @{ includesAll = $true; includes = @() }
                businessConcepts = @{ includesAll = $false; includes = @("DataProduct") }
                dataProductTypes = @{ includesAll = $true; includes = @() }
            }
        }
        attributes = @(
            @{ type="string"; status="Published"; name="Snowflake Database"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Snowflake Schema"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Snowflake Tables"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Snowflake Source FQN Prefix"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
            @{ type="string"; status="Published"; name="Snowflake Last Refresh (UTC)"; isOptional=$true; scope=@{ inheritApplicableConstructsFromGroup=$true }; options=@{} }
        )
    }

    if ($existing) {
        $bodyObj.id = $existing.id
        $body = $bodyObj | ConvertTo-Json -Depth 10
        $r = Invoke-WebRequest -Uri "$dgBase/customMetadata/$($existing.id)$api" -Headers $headers -Method Put -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -eq 200) {
            Write-Host "  updated: Snowflake Source Metadata ($($existing.id))" -ForegroundColor Green
        } elseif ($r.StatusCode -eq 400) {
            Write-Host "  keep existing: Snowflake Source Metadata ($($existing.id)) (immutable fields rejected by API)" -ForegroundColor DarkYellow
        } else {
            Write-Host "  warn: update Snowflake Source Metadata -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
        }
    } else {
        $body = $bodyObj | ConvertTo-Json -Depth 10
        $r = Invoke-WebRequest -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
        if ($r.StatusCode -in 200, 201) {
            $obj = (Read-TextContent $r) | ConvertFrom-Json
            Write-Host "  created: Snowflake Source Metadata ($($obj.id))" -ForegroundColor Green
        } else {
            Write-Host "  warn: create Snowflake Source Metadata -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
        }
    }
}

function Set-DqClassificationTypes {
    Write-Host "`n=== Ensure Atlas DQ classification typedefs ===" -ForegroundColor Cyan

    $tiers = @(
        @{ name = "DQ_Gold"; desc = "Demo DQ tier: score 90-100" }
        @{ name = "DQ_Silver"; desc = "Demo DQ tier: score 75-89" }
        @{ name = "DQ_Bronze"; desc = "Demo DQ tier: score < 75" }
    )

    $typesUri = "$atlasBase/types/typedefs"
    $existing = Invoke-RestMethod -Uri $typesUri -Headers $headers -Method Get
    $existingNames = @()
    if ($existing.classificationDefs) { $existingNames = $existing.classificationDefs.name }

    $missing = @()
    foreach ($t in $tiers) {
        if ($existingNames -notcontains $t.name) {
            $missing += @{
                category = "CLASSIFICATION"
                name = $t.name
                description = $t.desc
                typeVersion = "1.0"
                attributeDefs = @()
                superTypes = @()
            }
        }
    }

    if ($missing.Count -gt 0) {
        $tdBody = @{ classificationDefs = $missing } | ConvertTo-Json -Depth 8
        $r = Invoke-WebRequest -Uri $typesUri -Headers $headers -Method Post -Body $tdBody -SkipHttpErrorCheck
        if ($r.StatusCode -in 200, 201) {
            Write-Host "  created $($missing.Count) typedef(s)" -ForegroundColor Green
        } else {
            Write-Host "  warn: typedef creation -> HTTP $($r.StatusCode)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  all DQ typedefs already exist" -ForegroundColor DarkGreen
    }
}

function Add-Relationship($dpId, $entityId, $entityType) {
    $body = @{ entityId = $entityId } | ConvertTo-Json -Compress
    $url = "$dgBase/dataproducts/$dpId/relationships$api&entityType=$entityType"
    $r = Invoke-WebRequest -Uri $url -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
    $content = Read-TextContent $r

    if ($r.StatusCode -eq 200) {
        return @{ ok = $true; already = $false }
    }

    if ($r.StatusCode -eq 409 -or $content -match "already" -or $content -match "exist") {
        return @{ ok = $true; already = $true }
    }

    return @{ ok = $false; already = $false; status = $r.StatusCode }
}

function Get-ExistingRelationshipEntityIds($dpId, $entityType) {
    $url = "$dgBase/dataproducts/$dpId/relationships$api&entityType=$entityType"
    $result = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if (-not $result -or -not $result.value) { return @() }
    return @($result.value | ForEach-Object { $_.entityId } | Where-Object { $_ })
}

function Add-DqClassification($atlasGuid, $classificationName) {
    $clsBody = @(@{ typeName = $classificationName; propagate = $false }) | ConvertTo-Json -Depth 4 -AsArray
    $url = "$atlasBase/entity/guid/$atlasGuid/classifications"
    $r = Invoke-WebRequest -Uri $url -Headers $headers -Method Post -Body $clsBody -SkipHttpErrorCheck
    $content = Read-TextContent $r

    if ($r.StatusCode -in 200, 204) { return @{ ok = $true; already = $false } }
    if ($r.StatusCode -eq 409 -or $content -match "already") { return @{ ok = $true; already = $true } }
    if ($r.StatusCode -eq 404) { return @{ ok = $true; already = $true } }

    return @{ ok = $false; already = $false; status = $r.StatusCode }
}

function Test-IsGuid($value) {
    if (-not $value) { return $false }
    return [System.Guid]::TryParse($value, [ref]([guid]::Empty))
}

# Curated mapping: Data Product -> matching keywords + term names + DQ tier
$dpConfig = @{
    "Executive Financial Dashboards" = @{
        assetKeywords = @("finance", "financial", "fsi", "cco", "kpi", "budget", "fact_sale")
        terms = @("Revenue", "Profitability", "Budget", "Forecast", "Return on Investment", "KPI")
        dqTier = "DQ_Gold"
    }
    "ESG and CSRD Reporting Pack" = @{
        assetKeywords = @("esg", "csrd", "sustainability", "emission", "carbon")
        terms = @("KPI", "Region", "Country", "Currency", "Data Quality Score")
        dqTier = "DQ_Silver"
    }
    "Customer 360" = @{
        assetKeywords = @("customer", "crm", "salesforce", "contoso")
        terms = @("Customer", "Customer Satisfaction", "Customer Master Record", "Customer Lifecycle")
        dqTier = "DQ_Gold"
    }
    "Workforce Analytics Dashboard" = @{
        assetKeywords = @("hr", "employee", "workforce", "headcount")
        terms = @("Employee", "Region", "Country", "KPI", "Business Unit")
        dqTier = "DQ_Silver"
    }
    "Operational Performance Hub" = @{
        assetKeywords = @("operation", "equipment", "maintenance", "inspection", "ramses", "sap")
        terms = @("Asset", "Equipment", "KPI", "Data Quality Score")
        dqTier = "DQ_Silver"
    }
    "Data Platform Health Monitor" = @{
        assetKeywords = @("purview", "platform", "lineage", "monitor", "health")
        terms = @("Data Quality Score", "Lineage", "Classification", "Governance Domain", "Data Product")
        dqTier = "DQ_Bronze"
    }
    "Convergence B2B" = @{
        assetKeywords = @("convergence", "b2b", "wwi", "opportunity")
        terms = @("Customer", "Revenue", "Opportunity", "KPI")
        dqTier = "DQ_Silver"
    }
    "RC Datahub Inspection" = @{
        assetKeywords = @("inspection", "quality", "equipment", "wwi")
        terms = @("Asset", "Inspection", "Equipment", "Data Quality Score")
        dqTier = "DQ_Silver"
    }
    "Books Analytics &  Forecasting" = @{
        assetKeywords = @("book", "forecast", "sales", "fact")
        terms = @("Revenue", "Forecast", "Customer", "KPI", "Fiscal Year")
        dqTier = "DQ_Silver"
    }
}

# --- Execution ---
Set-DqCustomMetadataGroup
Set-SnowflakeCustomMetadataGroup
Set-DqClassificationTypes

Write-Host "`n=== Load Data Products / Data Assets / Terms ===" -ForegroundColor Cyan
$allDp = (Invoke-RestMethod -Uri "$dgBase/dataproducts$api" -Headers $headers -Method Get).value
$allAssets = (Invoke-RestMethod -Uri "$dgBase/dataAssets$api&top=2000" -Headers $headers -Method Get).value
$allTerms = (Invoke-RestMethod -Uri "$dgBase/terms$api&top=2000" -Headers $headers -Method Get).value

$snowflakeAssets = @($allAssets | Where-Object { $_.source -and $_.source.assetType -eq "snowflake_table" })
Write-Host "Snowflake tables found: $($snowflakeAssets.Count)" -ForegroundColor Yellow

$targetDps = $allDp | Where-Object { $dpConfig.ContainsKey($_.name) }
Write-Host "Data Products target: $($targetDps.Count)" -ForegroundColor Yellow
Write-Host "Data Assets loaded: $($allAssets.Count)" -ForegroundColor Yellow
Write-Host "Terms loaded: $($allTerms.Count)" -ForegroundColor Yellow

$assetLinksOk = 0
$assetLinksAlready = 0
$assetLinksFail = 0
$termLinksOk = 0
$termLinksAlready = 0
$termLinksFail = 0

# atlasGuid -> dqTier (keep strongest tier if overlaps)
$tierRank = @{ DQ_Bronze = 1; DQ_Silver = 2; DQ_Gold = 3 }
$assetTierByAtlasGuid = @{}
$assetNameByAtlasGuid = @{}

foreach ($dp in $targetDps) {
    $cfg = $dpConfig[$dp.name]
    Write-Host "`n>>> $($dp.name)" -ForegroundColor Cyan

    $existingAssetIds = Get-ExistingRelationshipEntityIds -dpId $dp.id -entityType "DataAsset"
    $existingTermIds = Get-ExistingRelationshipEntityIds -dpId $dp.id -entityType "Term"

    # Match assets by keyword in name
    $matchedAssets = @()
    foreach ($kw in $cfg.assetKeywords) {
        $matchedAssets += $allAssets | Where-Object {
            $_.name -and $_.name.ToLower().Contains($kw.ToLower())
        }
    }
    $matchedAssets = @($matchedAssets | Sort-Object id -Unique | Select-Object -First 10)

    # Add Snowflake tables for all data products so Snowflake metadata is consistently reusable.
    if ($snowflakeAssets.Count -gt 0) {
        $matchedAssets = @($matchedAssets + $snowflakeAssets)
        $matchedAssets = @($matchedAssets | Sort-Object id -Unique)
    }

    foreach ($a in $matchedAssets) {
        if ($a.source -and $a.source.assetId) {
            $atlasGuid = $a.source.assetId
            if (Test-IsGuid $atlasGuid) {
                if (-not $assetTierByAtlasGuid.ContainsKey($atlasGuid)) {
                    $assetTierByAtlasGuid[$atlasGuid] = $cfg.dqTier
                    $assetNameByAtlasGuid[$atlasGuid] = $a.name
                } else {
                    $current = $assetTierByAtlasGuid[$atlasGuid]
                    if ($tierRank[$cfg.dqTier] -gt $tierRank[$current]) {
                        $assetTierByAtlasGuid[$atlasGuid] = $cfg.dqTier
                    }
                }
            }
        }

        if ($existingAssetIds -contains $a.id) {
            $assetLinksAlready++
            Write-Host "  = asset already linked: $($a.name)" -ForegroundColor DarkGray
            continue
        }

        $res = Add-Relationship -dpId $dp.id -entityId $a.id -entityType "DataAsset"
        if ($res.ok -and -not $res.already) {
            $assetLinksOk++
            $existingAssetIds += $a.id
            Write-Host "  + asset: $($a.name)" -ForegroundColor Green
        } elseif ($res.ok -and $res.already) {
            $assetLinksAlready++
            Write-Host "  = asset already linked: $($a.name)" -ForegroundColor DarkGray
        } else {
            $assetLinksFail++
            Write-Host "  ! asset link failed: $($a.name) -> HTTP $($res.status)" -ForegroundColor Yellow
        }

    }

    $matchedTerms = @()
    foreach ($tName in $cfg.terms) {
        $matchedTerms += $allTerms | Where-Object { $_.name -eq $tName }
    }
    $matchedTerms = $matchedTerms | Sort-Object id -Unique

    foreach ($t in $matchedTerms) {
        if ($existingTermIds -contains $t.id) {
            $termLinksAlready++
            Write-Host "  = term already linked: $($t.name)" -ForegroundColor DarkGray
            continue
        }

        $res = Add-Relationship -dpId $dp.id -entityId $t.id -entityType "Term"
        if ($res.ok -and -not $res.already) {
            $termLinksOk++
            $existingTermIds += $t.id
            Write-Host "  + term : $($t.name)" -ForegroundColor Green
        } elseif ($res.ok -and $res.already) {
            $termLinksAlready++
            Write-Host "  = term already linked: $($t.name)" -ForegroundColor DarkGray
        } else {
            $termLinksFail++
            Write-Host "  ! term link failed: $($t.name) -> HTTP $($res.status)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n=== Apply DQ classification on linked assets ===" -ForegroundColor Cyan
$dqOk = 0
$dqAlready = 0
$dqFail = 0

foreach ($atlasGuid in $assetTierByAtlasGuid.Keys) {
    $tier = $assetTierByAtlasGuid[$atlasGuid]
    $name = $assetNameByAtlasGuid[$atlasGuid]
    $res = Add-DqClassification -atlasGuid $atlasGuid -classificationName $tier
    if ($res.ok -and -not $res.already) {
        $dqOk++
        Write-Host "  + $tier on $name" -ForegroundColor Green
    } elseif ($res.ok -and $res.already) {
        $dqAlready++
        Write-Host "  = $tier already on $name" -ForegroundColor DarkGray
    } else {
        $dqFail++
        Write-Host "  ! DQ classification failed on $name -> HTTP $($res.status)" -ForegroundColor Yellow
    }
}

Write-Host "`n========== Summary ==========" -ForegroundColor Cyan
Write-Host "DataAsset links: created=$assetLinksOk already=$assetLinksAlready failed=$assetLinksFail"
Write-Host "Term links:      created=$termLinksOk already=$termLinksAlready failed=$termLinksFail"
Write-Host "DQ tags:         created=$dqOk already=$dqAlready failed=$dqFail"
Write-Host "Done." -ForegroundColor Green
