$pbiTok = (az account get-access-token --resource "https://analysis.windows.net/powerbi/api" --query accessToken -o tsv)
if (-not $pbiTok) { Write-Error "No PBI token"; exit 1 }
$h = @{ Authorization = "Bearer $pbiTok"; "Content-Type" = "application/json" }
$user = "demopde@mngenvmcap965390.onmicrosoft.com"

$workspaces = @(
    @{ id = "91b2dca3-5729-4e7d-a473-bfeb85c16aa1"; name = "Demo_Hachette" }
    @{ id = "9533dbdf-6c6b-42e1-9812-063987743389"; name = "Fabric_WWI" }
    @{ id = "7000dcc5-3063-4dc7-99f5-965d551c2083"; name = "DDiB-FSI" }
    @{ id = "11703875-6d34-4b38-9460-aa16840f0f67"; name = "Agile HR Analytics - AppSource" }
    @{ id = "60eec89d-aabb-4426-9ebb-476883d12ed6"; name = "Admin monitoring" }
    @{ id = "ac726c00-08b4-43ed-a154-fa7d3afd3daf"; name = "Fabric-DemoChurn" }
    @{ id = "2aa0bd5e-67f6-45de-bd8b-baa548dd810c"; name = "Customer" }
)

foreach ($w in $workspaces) {
    $body = @{ emailAddress = $user; groupUserAccessRight = "Viewer" } | ConvertTo-Json
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$($w.id)/users"
    $r = Invoke-WebRequest -Uri $url -Headers $h -Method Post -Body $body -SkipHttpErrorCheck
    $c = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
    $status = $r.StatusCode
    if ($status -in 200,201) {
        Write-Host ("  OK   {0,-35} (HTTP {1})" -f $w.name, $status) -ForegroundColor Green
    } elseif ($c -match "already exists|UserAlreadyExists|already added") {
        Write-Host ("  SKIP {0,-35} (already member)" -f $w.name) -ForegroundColor Yellow
    } else {
        Write-Host ("  FAIL {0,-35} (HTTP {1}) {2}" -f $w.name, $status, $c.Substring(0,[Math]::Min(200,$c.Length))) -ForegroundColor Red
    }
}
