# Simple notebook upload
$ErrorActionPreference = "Stop"
Set-Location "C:\Users\pidoudet\OneDrive - Microsoft\Boulot\PBI SME\OracleToPostgre\DemoPurview"

$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$WorkspaceId = "7000dcc5-3063-4dc7-99f5-965d551c2083"
$NotebookId = "76a29990-3e0c-4532-bbbd-a14ce1e5e489"

# Read notebook
$nbContent = Get-Content ".\Fabric_Notebooks\SemanticLabs_FinanceReport_Metadata.ipynb" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($nbContent)
$base64 = [Convert]::ToBase64String($bytes)
Write-Host "Notebook size: $($nbContent.Length)"

# Upload definition
$body = @{ definition = @{ format = "ipynb"; parts = @( @{ path = "artifact.content.ipynb"; payload = $base64; payloadType = "InlineBase64" } ) } } | ConvertTo-Json -Depth 10
$uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/notebooks/$NotebookId/updateDefinition"

try {
    $resp = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body
    Write-Host "Upload OK: $($resp.StatusCode)"
    if ($resp.Headers["Location"]) {
        $loc = $resp.Headers["Location"][0]
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 2
            $st = Invoke-RestMethod -Uri $loc -Headers $headers
            Write-Host "[$i] $($st.status)"
            if ($st.status -eq "Succeeded" -or $st.status -eq "Failed") { break }
        }
    }
} catch {
    Write-Host "Error: $_"
}
