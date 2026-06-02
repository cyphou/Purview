param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$OutputDir = "docs"
)

$ErrorActionPreference = "Stop"

$base = "https://$PurviewAccount.purview.azure.com"
$ucApi = "2026-03-20-preview"

function Get-PurviewHeaders {
    $token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
    if (-not $token) {
        throw "Unable to get access token. Run 'az login' and retry."
    }
    return @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
}

function Get-PrincipalIdsFromRule {
    param([Parameter(Mandatory=$true)]$Rule)

    $ids = @()
    foreach ($conjunction in @($Rule.dnfCondition)) {
        foreach ($node in @($conjunction)) {
            foreach ($cond in @($node)) {
                if ($cond.attributeName -eq "principal.microsoft.id") {
                    $ids += @($cond.attributeValueIncludedIn)
                }
            }
        }
    }
    return $ids | Where-Object { $_ } | Select-Object -Unique
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$headers = Get-PurviewHeaders
$now = Get-Date

$demoUsersPath = Join-Path $PSScriptRoot "demo_users.json"
if (-not (Test-Path -LiteralPath $demoUsersPath)) {
    throw "demo_users.json not found at $demoUsersPath"
}

$demoUsers = Get-Content -LiteralPath $demoUsersPath | ConvertFrom-Json -AsHashtable
$userRows = @()
foreach ($k in $demoUsers.Keys) {
    $userRows += [pscustomobject]@{ persona = $k; objectId = $demoUsers[$k] }
}

$domainCount = ((Invoke-RestMethod "$base/datagovernance/catalog/businessdomains?api-version=$ucApi" -Headers $headers).value | Measure-Object).Count
$termCount = ((Invoke-RestMethod "$base/datagovernance/catalog/terms?api-version=$ucApi&top=200" -Headers $headers).value | Measure-Object).Count
$dpCount = ((Invoke-RestMethod "$base/datagovernance/catalog/dataproducts?api-version=$ucApi&top=200" -Headers $headers).value | Measure-Object).Count
$okrCount = ((Invoke-RestMethod "$base/datagovernance/catalog/objectives?api-version=$ucApi&top=200" -Headers $headers).value | Measure-Object).Count
$cdeCount = ((Invoke-RestMethod "$base/datagovernance/catalog/criticalDataElements?api-version=$ucApi&top=200" -Headers $headers).value | Measure-Object).Count

$pol = Invoke-RestMethod -Uri "$base/policystore/metadataPolicies?collectionName=$PurviewAccount&api-version=2021-07-01" -Headers $headers
$policy = $pol.values[0]
$rules = @($policy.properties.attributeRules)

$roleRows = @()
foreach ($rule in $rules) {
    $name = $rule.name
    if (-not $name) { continue }
    $roleName = $name -replace ":$PurviewAccount$", "" -replace "purviewmetadatarole_builtin_", ""
    $principals = Get-PrincipalIdsFromRule -Rule $rule

    if ($principals.Count -eq 0) { continue }

    $demoMembers = @()
    foreach ($u in $userRows) {
        if ($principals -contains $u.objectId) {
            $demoMembers += $u.persona
        }
    }

    $roleRows += [pscustomobject]@{
        role = $roleName
        principalCount = $principals.Count
        demoMemberCount = $demoMembers.Count
        demoMembers = ($demoMembers -join ", ")
    }
}

$personaRoleMap = @()
foreach ($u in $userRows) {
    $rolesForUser = @()
    foreach ($rule in $rules) {
        $name = $rule.name
        if (-not $name) { continue }
        $roleName = $name -replace ":$PurviewAccount$", "" -replace "purviewmetadatarole_builtin_", ""
        $principals = Get-PrincipalIdsFromRule -Rule $rule
        if ($principals -contains $u.objectId) {
            $rolesForUser += $roleName
        }
    }

    $personaRoleMap += [pscustomobject]@{
        persona = $u.persona
        objectId = $u.objectId
        roleCount = $rolesForUser.Count
        roles = ($rolesForUser | Sort-Object -Unique) -join ", "
    }
}

$summary = [pscustomobject]@{
    generatedAt = $now.ToString("s")
    purviewAccount = $PurviewAccount
    scenarioCoverage = @{
        scenario1 = "KPI understanding and lineage supported"
        scenario2 = "Domain and data product exploration supported"
        scenario3 = "Documentation and governance supported"
        scenario4 = "Admin and adoption evidence generated"
    }
    catalog = @{
        businessDomains = $domainCount
        terms = $termCount
        dataProducts = $dpCount
        objectives = $okrCount
        criticalDataElements = $cdeCount
    }
    demoUsers = $userRows
    roles = $roleRows
    personaRoles = $personaRoleMap
}

$jsonPath = Join-Path $OutputDir "scenario4_admin_adoption_evidence.json"
$mdPath = Join-Path $OutputDir "scenario4_admin_adoption_evidence.md"

$summary | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $jsonPath -Encoding utf8

$md = @()
$md += "# Scenario 4 Admin and Adoption Evidence"
$md += ""
$md += "Generated: $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$md += "Purview account: $PurviewAccount"
$md += ""
$md += "## Catalog coverage snapshot"
$md += ""
$md += "- Business domains: $domainCount"
$md += "- Terms: $termCount"
$md += "- Data products: $dpCount"
$md += "- Objectives (OKRs): $okrCount"
$md += "- Critical Data Elements: $cdeCount"
$md += ""
$md += "## Persona to role mapping"
$md += ""
$md += "| Persona | Role count | Roles |"
$md += "|---|---:|---|"
foreach ($row in ($personaRoleMap | Sort-Object persona)) {
    $md += "| $($row.persona) | $($row.roleCount) | $($row.roles) |"
}
$md += ""
$md += "## Metadata roles with demo membership"
$md += ""
$md += "| Role | Principals in role | Demo users in role | Demo members |"
$md += "|---|---:|---:|---|"
foreach ($row in ($roleRows | Sort-Object role)) {
    $md += "| $($row.role) | $($row.principalCount) | $($row.demoMemberCount) | $($row.demoMembers) |"
}
$md += ""
$md += "## Scenario 4 talking points"
$md += ""
$md += "- User and role management: demonstrated through persona to role mapping."
$md += "- Access and security: demonstrated through metadata policy membership evidence."
$md += "- Adoption baseline: catalog coverage and governance object counts are captured as run-time evidence."

$md -join "`r`n" | Out-File -LiteralPath $mdPath -Encoding utf8

Write-Host "Scenario 4 evidence generated:" -ForegroundColor Green
Write-Host "  - $jsonPath"
Write-Host "  - $mdPath"
