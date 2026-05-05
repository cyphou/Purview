# Add Pierre DOUDET to all Purview roles on root collection
$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$myId = "0738cec4-3dd2-4d28-86bc-9585d85eb511"

# Get current metadata policy for root collection
$pol = Invoke-RestMethod -Uri "https://pdedemopurv.purview.azure.com/policystore/metadataPolicies?collectionName=pdedemopurv&api-version=2021-07-01" -Headers $headers -Method Get
$policy = $pol.values[0]
$policyId = $policy.id
Write-Host "Policy ID: $policyId"

# Deep clone the policy to JSON for manipulation
$policyJson = $policy | ConvertTo-Json -Depth 20
$policyObj = $policyJson | ConvertFrom-Json

# Add my ID to each attribute rule that has principal.microsoft.id
$rolesUpdated = @()
foreach ($rule in $policyObj.properties.attributeRules) {
    if ($rule.name -eq "permission:pdedemopurv") { continue }
    
    $updated = $false
    # dnfCondition can be nested arrays
    foreach ($conjunction in $rule.dnfCondition) {
        # conjunction is an array of conditions
        $conditions = @($conjunction)
        foreach ($cond in $conditions) {
            if ($cond.attributeName -eq "principal.microsoft.id") {
                $existing = @($cond.attributeValueIncludedIn)
                if ($existing -notcontains $myId) {
                    $existing += $myId
                    $cond.attributeValueIncludedIn = $existing
                    $updated = $true
                }
            }
        }
    }
    if ($updated) {
        $roleName = $rule.name -replace ':pdedemopurv$','' -replace 'purviewmetadatarole_builtin_',''
        $rolesUpdated += $roleName
        Write-Host "  Updated: $roleName"
    }
}

if ($rolesUpdated.Count -eq 0) {
    Write-Host "No changes needed - user already in all roles"
    exit 0
}

# PUT the updated policy back
$updatedBody = $policyObj | ConvertTo-Json -Depth 20
try {
    $result = Invoke-RestMethod -Uri "https://pdedemopurv.purview.azure.com/policystore/metadataPolicies/$policyId`?api-version=2021-07-01" -Headers $headers -Method Put -Body $updatedBody -ErrorAction Stop
    Write-Host "`nPolicy updated successfully!"
    Write-Host "Roles added for Pierre DOUDET: $($rolesUpdated -join ', ')"
} catch {
    Write-Host "ERROR updating policy: $($_.Exception.Message)"
    # Show response body if available
    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $errBody = $reader.ReadToEnd()
    Write-Host "Response: $errBody"
}

# Verify: retry governance APIs
Write-Host "`n=== Retrying governance APIs ==="
$token = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

try {
    $r = Invoke-RestMethod -Uri "https://pdedemopurv.purview.azure.com/datagovernance/catalogs/default/governanceDomains?api-version=2025-02-01" -Headers $headers -Method Get -ErrorAction Stop
    Write-Host "Governance Domains API -> OK! Found: $($r.value.Count)"
    $r.value | ForEach-Object { Write-Host "  - $($_.name)" }
} catch {
    Write-Host "Governance Domains API -> $($_.Exception.Response.StatusCode)"
}
