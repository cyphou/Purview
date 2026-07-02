# Run notebook in Fabric
param(
    [string]$WorkspaceId = "7000dcc5-3063-4dc7-99f5-965d551c2083",
    [string]$NotebookId = "76a29990-3e0c-4532-bbbd-a14ce1e5e489"
)

$ErrorActionPreference = "Stop"
$token = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

Write-Host "Submitting notebook job..."
$body = @{ executionData = @{} } | ConvertTo-Json

$runUri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items/$NotebookId/jobs/instances?jobType=RunNotebook"

try {
    $response = Invoke-WebRequest -Uri $runUri -Headers $headers -Method Post -Body $body
    Write-Host "Job submitted! Status: $($response.StatusCode)" -ForegroundColor Green
    
    # Get job location for polling
    $jobLocation = $null
    if ($response.Headers["Location"]) {
        $jobLocation = $response.Headers["Location"][0]
    }
    
    if ($jobLocation) {
        Write-Host "Polling job status at: $jobLocation"
        $maxAttempts = 60
        for ($i = 0; $i -lt $maxAttempts; $i++) {
            Start-Sleep -Seconds 10
            try {
                $jobStatus = Invoke-RestMethod -Uri $jobLocation -Headers $headers -Method Get
                Write-Host "[$i] Status: $($jobStatus.status)"
                
                if ($jobStatus.status -eq "Completed" -or $jobStatus.status -eq "Succeeded") {
                    Write-Host "Job completed successfully!" -ForegroundColor Green
                    $jobStatus | ConvertTo-Json -Depth 5
                    break
                } elseif ($jobStatus.status -eq "Failed" -or $jobStatus.status -eq "Cancelled") {
                    Write-Host "Job failed or cancelled!" -ForegroundColor Red
                    $jobStatus | ConvertTo-Json -Depth 5
                    break
                }
            } catch {
                Write-Host "Polling error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "Error submitting job: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        Write-Host "Error details: $errorBody"
    }
}
