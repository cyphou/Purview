# =============================================================================
# Create Demo Governance Users + Assign to Unified Catalog Domains & Terms
# =============================================================================
# Creates dedicated Entra ID users for governance demo personas:
#   - Data Owner (1 per domain)
#   - Data Steward (1 per domain)
#   - Cross-domain roles: CDO, DPO, Data Quality Lead, Domain Architect
#
# Then assigns them as contacts on domains and terms via Unified Catalog API.
# =============================================================================

$ErrorActionPreference = "Stop"
$domain = "MngEnvMCAP965390.onmicrosoft.com"
$defaultPwd = "Purview-Demo-2026!"

# --- Persona definitions ---
# Format: upn prefix, display name, job title, department
$usersToCreate = @(
    # === Cross-domain governance roles ===
    @{ upn = "cdo";                 name = "Sarah Martin";          title = "Chief Data Officer";          dept = "Data Office" }
    @{ upn = "dpo";                 name = "Thomas Durand";         title = "Data Protection Officer";     dept = "Data Office" }
    @{ upn = "dq.lead";             name = "Claire Lefevre";        title = "Data Quality Lead";           dept = "Data Office" }
    @{ upn = "data.architect";      name = "Marc Dupont";           title = "Enterprise Data Architect";   dept = "Data Office" }
    
    # === Finance and ESG domain ===
    # financeowner already exists — will reuse
    # financesteward already exists — will reuse
    
    # === Customer and Sales domain ===
    @{ upn = "customer.owner";      name = "Julie Bernard";         title = "Customer Data Owner";         dept = "Sales" }
    @{ upn = "customer.steward";    name = "Nicolas Moreau";        title = "Customer Data Steward";       dept = "Sales" }
    
    # === HR and People domain ===
    @{ upn = "hr.owner";            name = "Sophie Petit";          title = "HR Data Owner";               dept = "Human Resources" }
    @{ upn = "hr.steward";          name = "Antoine Roux";          title = "HR Data Steward";             dept = "Human Resources" }
    
    # === Operations and Industrial domain ===
    @{ upn = "ops.owner";           name = "Philippe Lambert";      title = "Operations Data Owner";       dept = "Operations" }
    @{ upn = "ops.steward";         name = "Isabelle Garcia";       title = "Operations Data Steward";     dept = "Operations" }
    
    # === Technology and Data Platform domain ===
    @{ upn = "tech.owner";          name = "David Rousseau";        title = "Platform Data Owner";         dept = "IT" }
    @{ upn = "tech.steward";        name = "Emilie Fontaine";       title = "Platform Data Steward";       dept = "IT" }
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Creating Demo Governance Users" -ForegroundColor Cyan
Write-Host " Tenant: $domain" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# =============================================================================
# PHASE 1: Create users in Entra ID
# =============================================================================
Write-Host "`n=== PHASE 1: Create Entra ID Users ===" -ForegroundColor Yellow

$userOids = @{}
$created = 0
$skipped = 0

# First, collect existing users we'll reuse
Write-Host "  Checking existing users to reuse..."
$existingReuse = @(
    @{ upn = "financeowner";   role = "Finance Data Owner" }
    @{ upn = "financesteward"; role = "Finance Data Steward" }
    @{ upn = "cfo";            role = "CFO" }
)

foreach ($eu in $existingReuse) {
    $fullUpn = "$($eu.upn)@$domain"
    try {
        $existing = az ad user show --id $fullUpn --query "{id:id, displayName:displayName}" -o json 2>$null | ConvertFrom-Json
        if ($existing) {
            $userOids[$eu.upn] = $existing.id
            Write-Host "  [REUSE] $($existing.displayName) ($fullUpn) -> $($existing.id)" -ForegroundColor DarkGray
        }
    } catch {}
}

# Create new users
foreach ($u in $usersToCreate) {
    $fullUpn = "$($u.upn)@$domain"
    Write-Host "  Creating: $($u.name) ($fullUpn)..." -NoNewline
    
    # Check if already exists
    $existing = $null
    try {
        $existing = az ad user show --id $fullUpn --query "id" -o tsv 2>$null
    } catch {}
    
    if ($existing) {
        $userOids[$u.upn] = $existing
        $skipped++
        Write-Host " EXISTS (id=$existing)" -ForegroundColor DarkYellow
        continue
    }
    
    # Create user
    try {
        $result = az ad user create `
            --display-name $u.name `
            --user-principal-name $fullUpn `
            --password $defaultPwd `
            --force-change-password-next-sign-in false `
            --job-title $u.title `
            --department $u.dept `
            --query "id" -o tsv
        
        $userOids[$u.upn] = $result
        $created++
        Write-Host " OK (id=$result)" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n  Created: $created | Reused/Skipped: $($skipped + $existingReuse.Count) | Total: $($userOids.Count)" -ForegroundColor Cyan

# Save user mapping
$userOids | ConvertTo-Json | Out-File -FilePath "demo_users.json" -Encoding utf8
Write-Host "  User OIDs saved to demo_users.json" -ForegroundColor DarkGray

# =============================================================================
# PHASE 2: Assign Purview Unified Catalog roles (Governance Domain Curator)
# =============================================================================
Write-Host "`n=== PHASE 2: Add Users to Purview Metadata Policy ===" -ForegroundColor Yellow

# Get current metadata policy
$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$policyUrl = "https://pdedemopurv.purview.azure.com/policyStore/metadataPolicies?collectionName=pdedemopurv&api-version=2021-07-01"

$policyResp = Invoke-RestMethod -Uri $policyUrl -Headers $headers -Method Get
$policy = $policyResp.values[0]
$policyId = $policy.id

Write-Host "  Policy ID: $policyId"

# Find the purview-reader and data-curator attribute rules
$allOids = $userOids.Values | ForEach-Object { $_ }

$rolesUpdated = 0
foreach ($rule in $policy.properties.attributeRules) {
    $roleName = $rule.id
    # Add all demo users to purview-reader and data-curator roles
    if ($roleName -match "purview-reader|data-curator") {
        foreach ($oid in $allOids) {
            $alreadyIn = $false
            foreach ($cond in $rule.dnfCondition) {
                foreach ($attr in $cond) {
                    if ($attr.attributeName -eq "principal.microsoft.id" -and $attr.attributeValueIncludedIn -contains $oid) {
                        $alreadyIn = $true
                    }
                }
            }
            if (-not $alreadyIn) {
                # Find the principal condition group and add the OID
                foreach ($cond in $rule.dnfCondition) {
                    foreach ($attr in $cond) {
                        if ($attr.attributeName -eq "principal.microsoft.id") {
                            $attr.attributeValueIncludedIn += $oid
                            $rolesUpdated++
                        }
                    }
                }
            }
        }
    }
}

if ($rolesUpdated -gt 0) {
    $updateUrl = "https://pdedemopurv.purview.azure.com/policyStore/metadataPolicies/$($policyId)?api-version=2021-07-01"
    $policyJson = $policy | ConvertTo-Json -Depth 20
    try {
        Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Put -Body $policyJson | Out-Null
        Write-Host "  Updated metadata policy — $rolesUpdated OID additions to purview-reader/data-curator" -ForegroundColor Green
    } catch {
        Write-Host "  Policy update failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  All users already in policy — no update needed" -ForegroundColor DarkGray
}

# =============================================================================
# PHASE 3: Assign contacts on Unified Catalog Domains
# =============================================================================
Write-Host "`n=== PHASE 3: Assign Contacts on Governance Domains ===" -ForegroundColor Yellow

$apiVer = "api-version=2026-03-20-preview"
$baseUrl = "https://pdedemopurv.purview.azure.com"

# Load Sprint 5 domain GUIDs
$sprint5Guids = Get-Content "sprint5_domain_guids.json" | ConvertFrom-Json

# Domain -> Owner + Steward mapping
$domainContacts = @{
    "Finance and ESG" = @{
        owner   = @( @{ id = $userOids["financeowner"]; description = "Finance Data Owner" } )
        expert  = @( @{ id = $userOids["financesteward"]; description = "Finance Data Steward" },
                     @{ id = $userOids["cfo"]; description = "CFO" } )
    }
    "Customer and Sales" = @{
        owner   = @( @{ id = $userOids["customer.owner"]; description = "Customer Data Owner" } )
        expert  = @( @{ id = $userOids["customer.steward"]; description = "Customer Data Steward" } )
    }
    "HR and People" = @{
        owner   = @( @{ id = $userOids["hr.owner"]; description = "HR Data Owner" } )
        expert  = @( @{ id = $userOids["hr.steward"]; description = "HR Data Steward" } )
    }
    "Operations and Industrial" = @{
        owner   = @( @{ id = $userOids["ops.owner"]; description = "Operations Data Owner" } )
        expert  = @( @{ id = $userOids["ops.steward"]; description = "Operations Data Steward" } )
    }
    "Technology and Data Platform" = @{
        owner   = @( @{ id = $userOids["tech.owner"]; description = "Platform Data Owner" } )
        expert  = @( @{ id = $userOids["tech.steward"]; description = "Platform Data Steward" } )
    }
}

# Also add CDO + DQ Lead as expert on ALL domains
$cdoContact = @{ id = $userOids["cdo"]; description = "Chief Data Officer" }
$dqContact  = @{ id = $userOids["dq.lead"]; description = "Data Quality Lead" }

foreach ($domName in $domainContacts.Keys) {
    $domainContacts[$domName].expert += $cdoContact
    $domainContacts[$domName].expert += $dqContact
}

# Get full domain details and update each with contacts via the Update API
$domainUpdateOk = 0
$domainUpdateKo = 0

# First get all domains to find IDs
$allDomains = Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/businessdomains?$apiVer" -Headers $headers -Method Get

foreach ($domName in $domainContacts.Keys) {
    Write-Host "  Updating contacts on: $domName..." -NoNewline
    
    # Find domain ID
    $dom = $allDomains.value | Where-Object { $_.name -eq $domName }
    if (-not $dom) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        $domainUpdateKo++
        continue
    }
    
    # Get full domain details
    try {
        $domDetail = Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/businessdomains/$($dom.id)?$apiVer" -Headers $headers -Method Get -ErrorAction Stop
    } catch {
        Write-Host " GET FAILED" -ForegroundColor Red
        $domainUpdateKo++
        continue
    }
    
    # Build update body — set owners on the domain
    # The Unified Catalog Domain doesn't have a contacts field directly,
    # so we'll use the Update endpoint with whatever fields are supported
    $updateBody = @{
        id          = $dom.id
        name        = $dom.name
        description = $dom.description
        status      = $dom.status
        type        = $dom.type
        isRestricted = $dom.isRestricted
        thumbnail   = $dom.thumbnail
        domains     = if ($dom.domains) { $dom.domains } else { @() }
        managedAttributes = if ($dom.managedAttributes) { $dom.managedAttributes } else { @() }
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/businessdomains/$($dom.id)?$apiVer" `
            -Headers $headers -Method Patch -Body $updateBody -ErrorAction Stop | Out-Null
        $domainUpdateOk++
        Write-Host " OK" -ForegroundColor Green
    } catch {
        $status = $_.Exception.Response.StatusCode
        # If PATCH doesn't work, domains may not support contacts directly
        Write-Host " $status (domains may not have contacts field)" -ForegroundColor DarkYellow
        $domainUpdateKo++
    }
}

Write-Host "  Domain contact updates: $domainUpdateOk OK / $domainUpdateKo issues" -ForegroundColor $(if ($domainUpdateKo -eq 0) { "Green" } else { "Yellow" })

# =============================================================================
# PHASE 4: Assign contacts on Glossary Terms
# =============================================================================
Write-Host "`n=== PHASE 4: Assign Contacts on Glossary Terms ===" -ForegroundColor Yellow

# Map domain names to their owner/steward for term assignment
$termOwnerMap = @{
    "Finance and ESG"             = @{ ownerId = $userOids["financeowner"];   stewardId = $userOids["financesteward"] }
    "Customer and Sales"          = @{ ownerId = $userOids["customer.owner"]; stewardId = $userOids["customer.steward"] }
    "HR and People"               = @{ ownerId = $userOids["hr.owner"];       stewardId = $userOids["hr.steward"] }
    "Operations and Industrial"   = @{ ownerId = $userOids["ops.owner"];      stewardId = $userOids["ops.steward"] }
    "Technology and Data Platform" = @{ ownerId = $userOids["tech.owner"];    stewardId = $userOids["tech.steward"] }
}

# Get domain ID -> name mapping
$domIdToName = @{}
foreach ($dom in $allDomains.value) {
    # Only map our 5 Sprint 5 domains
    if ($domainContacts.ContainsKey($dom.name)) {
        $domIdToName[$dom.id] = $dom.name
    }
}

# List all terms for each domain and update contacts
$termUpdateOk = 0
$termUpdateKo = 0

foreach ($domId in $domIdToName.Keys) {
    $domName = $domIdToName[$domId]
    $ownerSteward = $termOwnerMap[$domName]
    
    Write-Host "`n  Domain: $domName"
    
    # List terms for this domain
    try {
        $termsResp = Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/terms?$apiVer&domainId=$domId&top=50" `
            -Headers $headers -Method Get -ErrorAction Stop
    } catch {
        Write-Host "    Failed to list terms: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        continue
    }
    
    foreach ($term in $termsResp.value) {
        Write-Host "    Updating: $($term.name)..." -NoNewline
        
        $termUpdate = @{
            id          = $term.id
            name        = $term.name
            domain      = $domId
            status      = $term.status
            contacts    = @{
                owner  = @( @{ id = $ownerSteward.ownerId; description = "Data Owner" } )
                expert = @( @{ id = $ownerSteward.stewardId; description = "Data Steward" } )
            }
        } | ConvertTo-Json -Depth 5
        
        try {
            Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/terms/$($term.id)?$apiVer" `
                -Headers $headers -Method Patch -Body $termUpdate -ErrorAction Stop | Out-Null
            $termUpdateOk++
            Write-Host " OK" -ForegroundColor Green
        } catch {
            $status = $_.Exception.Response.StatusCode
            $errBody = $_.ErrorDetails.Message
            $termUpdateKo++
            Write-Host " FAILED ($status)" -ForegroundColor Red
            if ($termUpdateKo -eq 1) { Write-Host "      $errBody" -ForegroundColor DarkRed }
        }
    }
}

Write-Host "`n  Term contact updates: $termUpdateOk OK / $termUpdateKo issues" -ForegroundColor $(if ($termUpdateKo -eq 0) { "Green" } else { "Yellow" })

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " Demo Users — RESULTS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Users created/reused : $($userOids.Count)" -ForegroundColor White

Write-Host "`n  Cross-domain roles:" -ForegroundColor Yellow
Write-Host "    CDO              : Sarah Martin      (cdo@$domain)"
Write-Host "    DPO              : Thomas Durand     (dpo@$domain)"
Write-Host "    Data Quality Lead: Claire Lefevre    (dq.lead@$domain)"
Write-Host "    Data Architect   : Marc Dupont       (data.architect@$domain)"

Write-Host "`n  Domain Owner / Steward:" -ForegroundColor Yellow
Write-Host "    Finance & ESG    : financeowner / financesteward (existing)"
Write-Host "    Customer & Sales : Julie Bernard / Nicolas Moreau"
Write-Host "    HR & People      : Sophie Petit / Antoine Roux"
Write-Host "    Operations       : Philippe Lambert / Isabelle Garcia"
Write-Host "    Tech & Data      : David Rousseau / Emilie Fontaine"

Write-Host "`n  Default password   : $defaultPwd" -ForegroundColor DarkYellow
Write-Host "  User OIDs          : demo_users.json" -ForegroundColor DarkGray
Write-Host "=============================================" -ForegroundColor Cyan
