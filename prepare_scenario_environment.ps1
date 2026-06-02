param(
    [switch]$SkipMetadata,
    [switch]$SkipEvidence
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host "== Scenario Environment Preparation ==" -ForegroundColor Cyan

# 1) Validate Azure auth
$null = az account get-access-token --resource https://purview.azure.net --query accessToken -o tsv
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI authentication failed. Run 'az login' first."
}
Write-Host "Azure token check: OK" -ForegroundColor Green

# 2) Ensure core metadata and links for scenarios
if (-not $SkipMetadata) {
    Write-Host "Running complete metadata and DQ provisioning..." -ForegroundColor Yellow
    & "$repoRoot\complete_metadata_data_products_dq.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "complete_metadata_data_products_dq.ps1 failed"
    }
}

# 3) Ensure scenario 4 evidence artifacts
if (-not $SkipEvidence) {
    Write-Host "Generating scenario 4 evidence..." -ForegroundColor Yellow
    & "$repoRoot\scenario4_admin_adoption_evidence.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "scenario4_admin_adoption_evidence.ps1 failed"
    }
}

# 4) Build a local status artifact
$status = [ordered]@{
    generatedAt = (Get-Date).ToString("s")
    metadataProvisioned = (-not $SkipMetadata)
    evidenceProvisioned = (-not $SkipEvidence)
    evidenceFiles = [ordered]@{
        md = Test-Path "$repoRoot\docs\scenario4_admin_adoption_evidence.md"
        json = Test-Path "$repoRoot\docs\scenario4_admin_adoption_evidence.json"
    }
}

$status | ConvertTo-Json -Depth 6 | Set-Content -Path "$repoRoot\docs\scenario_environment_status.json" -Encoding utf8
Write-Host "Environment status written to docs/scenario_environment_status.json" -ForegroundColor Green
Write-Host "Scenario environment preparation completed." -ForegroundColor Green
