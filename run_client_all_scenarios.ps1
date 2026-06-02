param(
    [switch]$FullRebuild,
    [switch]$IncludeAdvanced,
    [switch]$RecreateDemoUsers,
    [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command '$Name'. Install it and retry."
    }
}

function Test-AzureAuth {
    try {
        $null = az account show --query id -o tsv
        $token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
        if (-not $token) { throw "No token returned." }
    }
    catch {
        throw "Azure authentication not ready. Run 'az login' and verify subscription context."
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$ScriptPath,
        [string[]]$Arguments = @(),
        [switch]$Optional
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        if ($Optional) {
            Write-Host "[SKIP] $Name (missing: $ScriptPath)" -ForegroundColor Yellow
            return
        }
        throw "Required script missing: $ScriptPath"
    }

    Write-Host "`n[RUN] $Name" -ForegroundColor Cyan
    Write-Host "      .\$ScriptPath $($Arguments -join ' ')" -ForegroundColor DarkGray

    try {
        & "$PSScriptRoot\$ScriptPath" @Arguments
        Write-Host "[OK]  $Name" -ForegroundColor Green
    }
    catch {
        if ($Optional) {
            Write-Host "[WARN] $Name failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return
        }
        throw
    }
}

Assert-Command -Name "az"
Test-AzureAuth

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Client Scenario Coverage Run" -ForegroundColor Cyan
Write-Host " Account: $PurviewAccount" -ForegroundColor Cyan
Write-Host " FullRebuild: $FullRebuild | IncludeAdvanced: $IncludeAdvanced | RecreateDemoUsers: $RecreateDemoUsers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Invoke-Step -Name "Add Purview roles (pre-flight)" -ScriptPath "add_purview_roles.ps1" -Optional

if ($FullRebuild) {
    Invoke-Step -Name "Full wipe and redeploy" -ScriptPath "wipe_and_redeploy.ps1"
}
else {
    Invoke-Step -Name "Scenario 1-3 baseline: domains" -ScriptPath "sprint2_domains_org.ps1"
    Invoke-Step -Name "Scenario 1-3 baseline: glossary" -ScriptPath "sprint3_glossary.ps1"
    Invoke-Step -Name "Scenario 1-3 baseline: data products" -ScriptPath "sprint4_data_products.ps1"
}

Invoke-Step -Name "Enrich data products" -ScriptPath "enrich_data_products.ps1"
Invoke-Step -Name "Unified catalog business features (OKR/CDE)" -ScriptPath "sprint5_unified_catalog.ps1"
Invoke-Step -Name "Business features add-on" -ScriptPath "add_business_features.ps1"
Invoke-Step -Name "Business processes" -ScriptPath "create_business_processes.ps1"

if ($IncludeAdvanced) {
    Invoke-Step -Name "LoB umbrella terms" -ScriptPath "add_lob_umbrella_terms.ps1" -Optional
    Invoke-Step -Name "DP to term links" -ScriptPath "attach_terms_to_dps.ps1" -Optional
    Invoke-Step -Name "Term/CDE relationships" -ScriptPath "sprint_uc_h_relationships.ps1" -Optional
    Invoke-Step -Name "CDE to critical columns" -ScriptPath "sprint_uc_i_critical_data_columns.ps1" -Optional
    Invoke-Step -Name "DQ tiers" -ScriptPath "sprint_uc_j_fake_data_quality.ps1" -Optional
}

if ($RecreateDemoUsers) {
    Invoke-Step -Name "Create/reuse demo users" -ScriptPath "create_demo_users.ps1"
}

Invoke-Step -Name "Assign owners" -ScriptPath "assign_owners.ps1"
Invoke-Step -Name "Verify owner assignments" -ScriptPath "verify_and_assign_owners.ps1" -Optional
Invoke-Step -Name "Add Purview roles (scenario 4)" -ScriptPath "add_purview_roles.ps1" -Optional

Invoke-Step -Name "Generate Scenario 4 evidence" -ScriptPath "scenario4_admin_adoption_evidence.ps1" -Arguments @("-PurviewAccount", $PurviewAccount)

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " DONE - Demo environment updated for scenarios 1-4" -ForegroundColor Green
Write-Host " Scenario 4 evidence: docs/scenario4_admin_adoption_evidence.md" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
