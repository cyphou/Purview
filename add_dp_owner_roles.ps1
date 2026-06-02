$token = (az account get-access-token --resource 'https://purview.azure.net' --query accessToken -o tsv)
$base = "https://2bfad6b9-88f6-4129-a60f-457babf01498-api.purview-service.microsoft.com"
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$adminId = "6617cad6-d329-4361-951a-9eacbbaa8049"

# Domain IDs and their dgdataqualityscope policy IDs
$domains = @{
    "0a789204-1d04-4743-a23c-00bcb988e7e2" = "506215fc-ac2e-436f-ab38-b994e3a9148e"
    "f1b1d5fe-3617-4786-9894-ffd8662bead7" = "a86b4ea5-2702-4e00-980d-a70a6753cf09"
    "7f5695d1-8e2e-44f1-9c08-5c1e2455cee7" = "2fb9fb89-09cd-49c4-84c1-793e7661e086"
    "da176475-282f-4f22-9a06-7661d0e25916" = "746c32e1-03a3-4af4-ad0c-344374e2c541"
    "2e6172a3-eb26-415f-96e4-cc5172828d13" = "53ad0225-f3d3-486c-8c19-a6efd4b7f8d1"
    "539074f3-1391-4ff7-9600-802a38dc671b" = "2e80ca45-9216-4355-89f0-b3e68888e721"
    "84f0ee4c-375b-4714-bd0d-a2d9dade9f36" = "f88d5e8c-808b-4bf6-bae2-fba3524c2270"
    "2fd7dfcd-875a-41ff-afd8-76dcf4084bc3" = "c91983f4-22af-4a61-8447-fdee230944d2"
    "f64840cf-bac7-4d21-b43f-b02b3e9f5ba6" = "5ba4a08f-c68c-4d75-aaa8-e138b28edec4"
}

foreach ($domainId in $domains.Keys) {
    $policyId = $domains[$domainId]
    Write-Host "`n=== Domain $domainId (dq policy $policyId) ==="
    
    $url = "$base/policystore/datagovernancePolicies/$policyId`?api-version=2023-06-01-preview"
    try {
        $policy = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    } catch {
        Write-Host "ERROR fetching: $($_.Exception.Message)"
        continue
    }
    
    $modified = $false
    
    # Add admin to data-product-owner and scope-administrator roles
    $rolesToUpdate = @(
        "purviewdatagovernancerole_builtin_data-product-owner:$domainId",
        "purviewdatagovernancerole_builtin_scope-administrator:$domainId"
    )
    
    foreach ($rule in $policy.properties.attributeRules) {
        if ($rule.id -in $rolesToUpdate) {
            foreach ($condGroup in $rule.dnfCondition) {
                foreach ($cond in $condGroup) {
                    if ($cond.attributeName -eq "principal.microsoft.id" -and $cond.attributeValueIncludedIn) {
                        if ($cond.attributeValueIncludedIn -notcontains $adminId) {
                            $list = [System.Collections.ArrayList]@($cond.attributeValueIncludedIn)
                            $list.Add($adminId) | Out-Null
                            $cond.attributeValueIncludedIn = $list.ToArray()
                            $modified = $true
                            Write-Host "Added admin to $($rule.id)"
                        } else {
                            Write-Host "Admin already in $($rule.id)"
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
            Write-Host "SUCCESS: Updated dq policy (version $($result.version))"
        } catch {
            $errCode = $_.Exception.Response.StatusCode.value__
            $errBody = $_.ErrorDetails.Message
            Write-Host "ERROR $errCode PUT: $errBody"
        }
    } else {
        Write-Host "No modification needed"
    }
}
