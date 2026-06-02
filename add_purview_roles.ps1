param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$AdminObjectId,
    [string]$AdminUpn,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$baseUrl = "https://$PurviewAccount.purview.azure.com"
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
if (-not $token) {
    throw "Unable to acquire Purview access token. Run az login first."
}
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

if (-not $AdminObjectId) {
    if ($AdminUpn) {
        $AdminObjectId = az ad user show --id $AdminUpn --query id -o tsv
    } else {
        $AdminObjectId = az ad signed-in-user show --query id -o tsv
    }

    if (-not $AdminObjectId) {
        throw "Could not resolve admin Object ID. Use -AdminObjectId (recommended) or a valid -AdminUpn."
    }
}

Write-Host "Purview account: $PurviewAccount"
Write-Host "Target admin Object ID: $AdminObjectId"

# Get current metadata policy for root collection
$pol = Invoke-RestMethod -Uri "$baseUrl/policystore/metadataPolicies?collectionName=$PurviewAccount&api-version=2021-07-01" -Headers $headers -Method Get
$policy = $pol.values[0]
$policyId = $policy.id
Write-Host "Policy ID: $policyId"

# Deep clone policy object to safely mutate nested arrays
$policyJson = $policy | ConvertTo-Json -Depth 20
$policyObj = $policyJson | ConvertFrom-Json

$rolesUpdated = @()
foreach ($rule in $policyObj.properties.attributeRules) {
    if ($rule.name -eq "permission:$PurviewAccount") { continue }

    $updated = $false
    foreach ($conjunction in $rule.dnfCondition) {
        $conditions = @($conjunction)
        foreach ($cond in $conditions) {
            if ($cond.attributeName -eq "principal.microsoft.id") {
                $existing = @($cond.attributeValueIncludedIn)
                if ($existing -notcontains $AdminObjectId) {
                    $existing += $AdminObjectId
                    $cond.attributeValueIncludedIn = $existing
                    $updated = $true
                }
            }
        }
    }

    if ($updated) {
        $roleName = $rule.name -replace ":$PurviewAccount$", "" -replace "purviewmetadatarole_builtin_", ""
        $rolesUpdated += $roleName
        Write-Host "  Updated: $roleName"
    }
}

if ($rolesUpdated.Count -eq 0) {
    Write-Host "No changes needed - user already in all roles"
    exit 0
}

if ($WhatIf) {
    Write-Host "WhatIf mode enabled - no policy update sent"
    Write-Host "Roles that would be updated: $($rolesUpdated -join ', ')"
    exit 0
}

$updatedBody = $policyObj | ConvertTo-Json -Depth 20
try {
    Invoke-RestMethod -Uri "$baseUrl/policystore/metadataPolicies/$policyId`?api-version=2021-07-01" -Headers $headers -Method Put -Body $updatedBody -ErrorAction Stop | Out-Null
    Write-Host "`nPolicy updated successfully"
    Write-Host "Roles granted to admin: $($rolesUpdated -join ', ')"
} catch {
    Write-Host "ERROR updating policy: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "Response: $errBody"
    }
    throw
}

# Verify effective access quickly against governance API
Write-Host "`n=== Verification ==="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalogs/default/governanceDomains?api-version=2025-02-01" -Headers $headers -Method Get -ErrorAction Stop
    Write-Host "Governance Domains API -> OK (count: $($r.value.Count))"
} catch {
    Write-Host "Governance Domains API -> FAILED: $($_.Exception.Message)"
    throw
}
