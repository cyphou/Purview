$token = (az account get-access-token --resource 'https://purview.azure.net' --query accessToken -o tsv)
$base = "https://2bfad6b9-88f6-4129-a60f-457babf01498-api.purview-service.microsoft.com"
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$adminId = "6617cad6-d329-4361-951a-9eacbbaa8049"

$domains = @{
    "0a789204-1d04-4743-a23c-00bcb988e7e2" = "1549eeaa-844b-4f0d-a1a3-2b2dbd054450"
    "f1b1d5fe-3617-4786-9894-ffd8662bead7" = "6e4be3f4-1cf2-4e9d-a44a-89b22c2e8ef7"
    "7f5695d1-8e2e-44f1-9c08-5c1e2455cee7" = "8b5d6e21-2071-45c0-8694-d4ebac690d36"
    "da176475-282f-4f22-9a06-7661d0e25916" = "77ba6b11-1c75-40a3-ada5-7b52b6e3fb91"
    "2e6172a3-eb26-415f-96e4-cc5172828d13" = "6be98253-909f-4314-a61c-e019b4a0089e"
    "539074f3-1391-4ff7-9600-802a38dc671b" = "4012f651-61c4-4c94-a539-d39f3aa6a476"
    "84f0ee4c-375b-4714-bd0d-a2d9dade9f36" = "f705f08e-6525-4b04-a4ec-be95a0c9df77"
    "2fd7dfcd-875a-41ff-afd8-76dcf4084bc3" = "f6a8f08b-dc6a-4a11-ba21-f7cfb44c98f4"
    "f64840cf-bac7-4d21-b43f-b02b3e9f5ba6" = "29f6af1b-be5b-497d-8156-230679c5568d"
}

foreach ($domainId in $domains.Keys) {
    $policyId = $domains[$domainId]
    Write-Host "`n=== Domain $domainId (policy $policyId) ==="
    
    $url = "$base/policystore/datagovernancePolicies/$policyId`?api-version=2023-06-01-preview"
    try {
        $policy = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    } catch {
        Write-Host "ERROR fetching: $($_.Exception.Message)"
        continue
    }
    
    $ownerRuleName = "purviewdatagovernancerole_builtin_business-domain-owner:$domainId"
    $modified = $false
    
    foreach ($rule in $policy.properties.attributeRules) {
        if ($rule.id -eq $ownerRuleName) {
            foreach ($condGroup in $rule.dnfCondition) {
                foreach ($cond in $condGroup) {
                    if ($cond.attributeName -eq "principal.microsoft.id" -and $cond.attributeValueIncludedIn) {
                        if ($cond.attributeValueIncludedIn -notcontains $adminId) {
                            $list = [System.Collections.ArrayList]@($cond.attributeValueIncludedIn)
                            $list.Add($adminId) | Out-Null
                            $cond.attributeValueIncludedIn = $list.ToArray()
                            $modified = $true
                            Write-Host "Added admin to owner rule"
                        } else {
                            Write-Host "Admin already in owner rule"
                        }
                    }
                }
            }
        }
    }
    
    if ($modified) {
        $body = $policy | ConvertTo-Json -Depth 20 -Compress
        try {
            $result = Invoke-RestMethod -Uri $url -Headers $headers -Method PUT -Body $body -ErrorAction Stop
            Write-Host "SUCCESS: Updated policy (version $($result.version))"
        } catch {
            $errCode = $_.Exception.Response.StatusCode.value__
            $errBody = $_.ErrorDetails.Message
            Write-Host "ERROR $errCode PUT: $errBody"
        }
    } else {
        Write-Host "No modification needed"
    }
}
