# Sprint UC-J : Fake Data Quality demo via custom-metadata + Atlas classifications
# Real DQ scoring requires the Spark scan service (managed identity, profiling job, rules,
# scan run). The /datagovernance/quality/scores endpoint is read-only and ignores
# api-version. So we simulate DQ governance using REST in two complementary ways:
#   1) Create "Data Quality" customMetadata group with 4 attributes (Score, Tier,
#      Last Scan Date, Active Rules) scoped to DataProduct + DataAsset.
#   2) Apply Atlas classifications (DQ-Gold/Silver/Bronze) to each DP's underlying
#      Atlas asset GUIDs so the asset chip shows the tier in Data Map / Lineage.
# Both paths are reversible. Values for option 1 still need portal entry per UC-D
# limitation (REST PUT silently drops `customMetadata` payloads on entities).

$token   = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$dgBase  = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$atlas   = "https://pdedemopurv.purview.azure.com/catalog/api/atlas/v2"
$api     = "?api-version=2026-03-20-preview"

# --- Option 1: customMetadata "Data Quality" group --------------------------------
Write-Host "=== Option 1: 'Data Quality' customMetadata group ===" -ForegroundColor Cyan
$existing = Invoke-RestMethod -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Get
$dqGroup  = $existing.value | Where-Object name -EQ "Data Quality"

$body = @{
    name        = "Data Quality"
    type        = "BusinessConcept"
    status      = "Published"
    description = "Manually maintained Data Quality KPIs (mirrors what the DQ Spark scanner would emit). Use for demo/governance of unscanned assets."
    scope       = @{
        applicableConstructs = @{
            domains             = @{ includesAll = $true; includes = @() }
                businessConcepts    = @{ includesAll = $false; includes = @("DataProduct") }
            dataProductTypes    = @{ includesAll = $true; includes = @() }
        }
    }
    attributes  = @(
        @{ type="string"; status="Published"; name="Quality Score (0-100)"; isOptional=$true; scope=@{inheritApplicableConstructsFromGroup=$true}; options=@{} }
        @{ type="string"; status="Published"; name="Quality Tier";          isOptional=$true; scope=@{inheritApplicableConstructsFromGroup=$true}; options=@{} }
        @{ type="string"; status="Published"; name="Last Scan Date";        isOptional=$true; scope=@{inheritApplicableConstructsFromGroup=$true}; options=@{} }
        @{ type="string"; status="Published"; name="Active Rules";          isOptional=$true; scope=@{inheritApplicableConstructsFromGroup=$true}; options=@{} }
        @{ type="string"; status="Published"; name="Last Scan Findings";    isOptional=$true; scope=@{inheritApplicableConstructsFromGroup=$true}; options=@{} }
    )
} | ConvertTo-Json -Depth 10

if ($dqGroup) {
    Write-Host "  exists id=$($dqGroup.id) -> PUT update" -ForegroundColor Yellow
    $r = Invoke-WebRequest -Uri "$dgBase/customMetadata/$($dqGroup.id)$api" -Headers $headers -Method Put -Body $body -SkipHttpErrorCheck
} else {
    $r = Invoke-WebRequest -Uri "$dgBase/customMetadata$api" -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
}
$c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
if ($r.StatusCode -in 200,201) {
    $gid = ($c | ConvertFrom-Json).id
    Write-Host "  ok  Data Quality group id=$gid (5 attributes)" -ForegroundColor Green
} else {
    Write-Host "  FAIL HTTP $($r.StatusCode) :: $($c.Substring(0,[Math]::Min(200,$c.Length)))" -ForegroundColor Red
}

# --- Option 2: Atlas classifications on UC dataAssets' underlying Atlas GUIDs -----
Write-Host "`n=== Option 2: Apply DQ-tier Atlas classifications ===" -ForegroundColor Cyan

# 2a) Define classification typedefs (idempotent)
# Atlas classification names cannot contain hyphens (letter + letter/digit/space/_)
$tiers = @(
    @{ name="DQ_Gold";   desc="Demo DQ tier: scanned, all critical rules passing, score 90-100" }
    @{ name="DQ_Silver"; desc="Demo DQ tier: minor rule failures, score 75-89" }
    @{ name="DQ_Bronze"; desc="Demo DQ tier: known issues, score < 75 or unscanned" }
)
$typesUri = "$atlas/types/typedefs"
$existingTypes = Invoke-RestMethod -Uri $typesUri -Headers $headers -Method Get
$existingNames = $existingTypes.classificationDefs.name
$newDefs = @()
foreach ($t in $tiers) {
    if ($existingNames -notcontains $t.name) {
        $newDefs += @{
            category    = "CLASSIFICATION"
            name        = $t.name
            description = $t.desc
            typeVersion = "1.0"
            attributeDefs = @()
            superTypes  = @()
        }
    }
}
if ($newDefs.Count -gt 0) {
    $tdBody = @{ classificationDefs = $newDefs } | ConvertTo-Json -Depth 8
    $r = Invoke-WebRequest -Uri $typesUri -Headers $headers -Method Post -Body $tdBody -SkipHttpErrorCheck
    $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    Write-Host "  Created $($newDefs.Count) classification typedefs -> HTTP $($r.StatusCode)" -ForegroundColor Green
} else {
    Write-Host "  All 3 classification typedefs already exist" -ForegroundColor DarkGreen
}

# 2b) Map UC dataAssets to a tier and apply via Atlas classification API
# Using UC dataAsset.source.assetId (the Atlas GUID) for the classification call.
$ucAssets = Invoke-RestMethod -Uri "$dgBase/dataAssets$api&top=200" -Headers $headers -Method Get

# Tier assignment plan: DPs we curated -> Gold; secondary assets -> Silver; rest -> Bronze
$gold = @("Finance Report","FSI CCO Dashboard","dimension_customer","fact_sale","Purview Hub","wwilakehouse-DirectLake")
$silver = @("dimension_date","dimension_city","aggregate_sale_by_date_employee","exec_requests_history","aggregate_sale_by_date_city","fact_sale (1)")
# Map display tier -> Atlas classification name (no hyphens allowed)
$tierName = @{ "DQ-Gold"="DQ_Gold"; "DQ-Silver"="DQ_Silver"; "DQ-Bronze"="DQ_Bronze" }

$applied = 0; $skipped = 0; $failed = 0
foreach ($a in $ucAssets.value) {
    $atlasGuid = $a.source.assetId
    if (-not $atlasGuid) { $skipped++; continue }
    $tier = if ($gold -contains $a.name) { "DQ-Gold" }
            elseif ($silver -contains $a.name) { "DQ-Silver" }
            else { "DQ-Bronze" }
    # Atlas expects a bare JSON array as the body
    $clsBody = @( @{ typeName = $tierName[$tier]; propagate = $false } ) | ConvertTo-Json -Depth 4 -AsArray
    $r = Invoke-WebRequest -Uri "$atlas/entity/guid/$atlasGuid/classifications" -Headers $headers -Method Post -Body $clsBody -SkipHttpErrorCheck
    $c = if($r.Content -is [byte[]]){[System.Text.Encoding]::UTF8.GetString($r.Content)}else{$r.Content}
    if ($r.StatusCode -in 200,204) {
        Write-Host "  ok  $tier on $($a.name)" -ForegroundColor Green
        $applied++
    } elseif ($r.StatusCode -eq 409 -or ($c -match "already associated" -or $c -match "already assigned" -or $c -match "AlreadyExists")) {
        Write-Host "  -- already classified: $($a.name)" -ForegroundColor DarkGray
        $skipped++
    } else {
        Write-Host "  FAIL $tier on $($a.name) [$atlasGuid] -> HTTP $($r.StatusCode) :: $($c.Substring(0,[Math]::Min(140,$c.Length)))" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n========== Summary ==========" -ForegroundColor Cyan
Write-Host "Custom metadata group 'Data Quality': created/updated"
Write-Host "Classifications applied: $applied | skipped (no atlas guid / pre-existing): $skipped | failed: $failed"
