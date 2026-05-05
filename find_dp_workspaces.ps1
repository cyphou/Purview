$tok = (az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv)
$h = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }
$base = "https://pdedemopurv.purview.azure.com/datagovernance/catalog"
$apiv = "api-version=2026-03-20-preview"

$dps = (Invoke-RestMethod -Uri "$base/dataProducts?$apiv" -Headers $h).value
$wsCount = @{}
$wsToDp  = @{}

foreach ($dp in $dps) {
    try { $rels = Invoke-RestMethod -Uri "$base/dataProducts/$($dp.id)/relationships?entityType=DataAsset&$apiv" -Headers $h } catch { continue }
    foreach ($rel in $rels.value) {
        try { $a = Invoke-RestMethod -Uri "$base/dataAssets/$($rel.entityId)?$apiv" -Headers $h } catch { continue }
        $wsId = $a.source.assetAttributes.workspaceId
        if (-not $wsId) {
            $fqn = $a.source.fqn
            if ($fqn -match "groups/([0-9a-f-]{36})") { $wsId = $matches[1] }
        }
        if ($wsId) {
            $wsCount[$wsId] = ($wsCount[$wsId] + 1)
            if (-not $wsToDp.ContainsKey($wsId)) { $wsToDp[$wsId] = @() }
            $wsToDp[$wsId] += $dp.name
        }
    }
}

Write-Host "Workspaces backing DP assets ($($wsCount.Count) workspaces):"
$wsCount.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $dpList = ($wsToDp[$_.Key] | Sort-Object -Unique) -join ", "
    Write-Host ("  ws={0}  assets={1}  dps=[{2}]" -f $_.Key, $_.Value, $dpList)
}
