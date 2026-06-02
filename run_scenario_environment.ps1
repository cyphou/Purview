param(
    [switch]$SkipPreparation
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$portalDir = Join-Path $repoRoot "purview-ux-portal"

if (-not $SkipPreparation) {
    & "$repoRoot\prepare_scenario_environment.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "prepare_scenario_environment.ps1 failed"
    }
}

Set-Location $portalDir

if (-not (Test-Path "$portalDir\node_modules")) {
    Write-Host "Installing portal dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed"
    }
}

Write-Host "Starting scenario portal on http://localhost:7071" -ForegroundColor Cyan
npm start
