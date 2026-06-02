$token = (az account get-access-token --resource 'https://purview.azure.net' --query accessToken -o tsv)
$base = "https://pdedemopurv.purview.azure.com"
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$adminId = "6617cad6-d329-4361-951a-9eacbbaa8049"

# The 9 blocked DPs with their IDs
$dps = @(
    @{ name = "Convergence B2B"; id = "69b2e6ee-d5e2-4cf0-832b-31f7ef12d9b8" }
    @{ name = "Customer 360"; id = "d59f93b0-26e7-4218-867a-c5b75a9c3e9f" }
    @{ name = "Data Platform Health Monitor"; id = "c0d1a63e-55e8-4b3a-ba99-d5e6ac9e13c7" }
    @{ name = "ESG and CSRD Reporting Pack"; id = "7b2c4d8e-9f31-4a6b-b5e0-8c3d72f1a4e6" }
    @{ name = "Executive Financial Dashboards"; id = "a4e8b2c1-3d7f-4956-9e0a-6b8c1d5f3a72" }
    @{ name = "New data product TDF"; id = "b3f7c9d2-8a41-4e6b-a0d5-7c2e1f9b4a83" }
    @{ name = "Operational Performance Hub"; id = "e5a1d8c3-6b94-4f2e-9d7a-3c0b8e1f5a26" }
    @{ name = "RC Datahub Inspection"; id = "f8c2b3a1-4d67-4e9b-85a0-9e1c3d7f2b84" }
    @{ name = "Workforce Analytics Dashboard"; id = "d6b9e4a2-7c83-4f15-a2d0-5e8b1c3a9f67" }
)

# First, get all DP details
Write-Host "Fetching all data products..."
$allDpsUrl = "$base/datagovernance/catalog/dataproducts?api-version=2026-03-20-preview"
$allDps = Invoke-RestMethod -Uri $allDpsUrl -Headers $headers -Method GET
Write-Host "Found $($allDps.value.Count) data products total"

foreach ($dpInfo in $allDps.value) {
    # Check if owner is already set to admin
    $ownerIds = @()
    if ($dpInfo.contacts -and $dpInfo.contacts.owner) {
        $ownerIds = $dpInfo.contacts.owner | ForEach-Object { $_.id }
    }
    
    if ($ownerIds -contains $adminId) {
        Write-Host "`n=== $($dpInfo.name) - ALREADY HAS ADMIN AS OWNER ==="
        continue
    }
    
    Write-Host "`n=== $($dpInfo.name) (id: $($dpInfo.id), domain: $($dpInfo.domain)) ==="
    
    # Add admin as owner
    $dpInfo.contacts.owner = @(@{ id = $adminId; description = "" })
    
    $dpUrl = "$base/datagovernance/catalog/dataproducts/$($dpInfo.id)?api-version=2026-03-20-preview"
    $body = $dpInfo | ConvertTo-Json -Depth 10 -Compress
    
    try {
        $result = Invoke-RestMethod -Uri $dpUrl -Headers $headers -Method PUT -Body $body -ErrorAction Stop
        Write-Host "SUCCESS: Owner set on '$($dpInfo.name)'"
    } catch {
        $errCode = $_.Exception.Response.StatusCode.value__
        $errBody = $_.ErrorDetails.Message
        Write-Host "ERROR $errCode : $errBody"
    }
}
