$tok = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$h = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$apiv = "api-version=2026-03-20-preview"

$dps = (Invoke-RestMethod -Uri "$base/dataProducts?$apiv" -Headers $h).value
$dp = $dps[0]
Write-Host "DP: $($dp.name)  id=$($dp.id)"
$rels = Invoke-RestMethod -Uri "$base/dataProducts/$($dp.id)/relationships?entityType=DataAsset&$apiv" -Headers $h
Write-Host "rels count: $($rels.value.Count)"
$rels.value | Select-Object -First 3 | ConvertTo-Json -Depth 6
if ($rels.value.Count -gt 0) {
    $first = $rels.value[0]
    Write-Host "`n--- First DataAsset full ---"
    $a = Invoke-RestMethod -Uri "$base/dataAssets/$($first.entityId)?$apiv" -Headers $h
    $a | ConvertTo-Json -Depth 8
}
