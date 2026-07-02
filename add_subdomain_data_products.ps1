param(
    [string]$PurviewAccount = "pdedemopurv"
)

$ErrorActionPreference = "Stop"

$baseUrl = "https://$PurviewAccount.purview.azure.com"
$ucApi = "2026-03-20-preview"

$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
if (-not $token) {
    throw "Unable to get access token. Run 'az login' and retry."
}

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Get-DomainByName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $domains = (Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/businessdomains?api-version=$ucApi&top=1000" -Headers $headers -Method Get).value
    return $domains | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Get-ExistingDataProducts {
    return (Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/dataproducts?api-version=$ucApi&top=1000" -Headers $headers -Method Get).value
}

function Get-DefaultContactId {
    param([Parameter(Mandatory = $true)]$Existing)

    $fromContacts = $Existing |
        ForEach-Object {
            if ($_.contacts -and $_.contacts.owner -and $_.contacts.owner.Count -gt 0) {
                $_.contacts.owner[0].id
            }
        } |
        Where-Object { $_ } |
        Select-Object -First 1

    if ($fromContacts) {
        return $fromContacts
    }

    $fromCreatedBy = $Existing |
        ForEach-Object {
            if ($_.systemData -and $_.systemData.createdBy) {
                $_.systemData.createdBy
            }
        } |
        Where-Object { $_ } |
        Select-Object -First 1

    if ($fromCreatedBy) {
        return $fromCreatedBy
    }

    try {
        $signedInUserId = az ad signed-in-user show --query id -o tsv
        if ($signedInUserId) {
            return $signedInUserId
        }
    } catch {
        # Fallbacks above should normally be enough in this demo tenant.
    }

    throw "Unable to resolve a default contact id for data product creation."
}

function New-SubdomainDataProduct {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Spec,
        [Parameter(Mandatory = $true)]$Domain,
        [Parameter(Mandatory = $true)][hashtable]$ExistingByName,
        [Parameter(Mandatory = $true)][string]$DefaultContactId
    )

    if ($ExistingByName.ContainsKey($Spec.name)) {
        Write-Host "  SKIP exists: $($Spec.name)" -ForegroundColor DarkYellow
        return $false
    }

    $payload = @{
        name = $Spec.name
        description = $Spec.description
        domain = $Domain.id
        type = "Dataset"
        status = "Published"
        contacts = @{
            owner = @(
                @{ id = $DefaultContactId }
            )
            expert = @(
                @{ id = $DefaultContactId }
            )
        }
    } | ConvertTo-Json -Depth 6

    $r = Invoke-WebRequest -Uri "$baseUrl/datagovernance/catalog/dataproducts?api-version=$ucApi" -Headers $headers -Method Post -Body $payload -SkipHttpErrorCheck

    if ($r.StatusCode -in 200, 201) {
        $created = $r.Content | ConvertFrom-Json
        Write-Host "  OK created: $($Spec.name) :: $($created.id)" -ForegroundColor Green
        return $true
    }

    $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
    throw "HTTP $($r.StatusCode) :: $content"
}

$specs = @(
    @{
        domainName = "Commercial Analytics"
        name = "Sales Pipeline Intelligence"
        description = "Unified sales pipeline KPIs with stage velocity, conversion funnel, and forecast confidence by region and channel. Supports weekly revenue governance reviews."
    },
    @{
        domainName = "Commercial Analytics"
        name = "Pricing and Discount Effectiveness"
        description = "Price realization, discount leakage, margin bridge, and win-rate impact analysis across product lines. Enables pricing governance and policy controls."
    },
    @{
        domainName = "Commercial Analytics"
        name = "Sell-out Performance Monitor"
        description = "Sell-out tracking by geography, partner, and product family with variance to target and out-of-stock alerts. Designed for commercial steering committees."
    },
    @{
        domainName = "CRM and Customer Data"
        name = "Customer Master Quality Hub"
        description = "Golden customer record quality dashboard with duplicate rate, completeness score, survivorship confidence, and stewardship backlog by business unit."
    },
    @{
        domainName = "CRM and Customer Data"
        name = "Consent and Preferences Compliance"
        description = "Customer consent status, communication preferences, and opt-in lifecycle metrics with policy conformance monitoring for regulated campaigns."
    }
)

Write-Host "=== Add sub-domain data products ===" -ForegroundColor Cyan

$existing = Get-ExistingDataProducts
$defaultContactId = Get-DefaultContactId -Existing $existing
Write-Host "Default contact id: $defaultContactId" -ForegroundColor DarkGray

$existingByName = @{}
foreach ($dp in $existing) {
    if ($dp.name) { $existingByName[$dp.name] = $dp }
}

$created = 0
$failed = 0

$grouped = $specs | Group-Object domainName
foreach ($group in $grouped) {
    $domainName = $group.Name
    Write-Host "`nSub-domain: $domainName" -ForegroundColor Yellow

    $domain = Get-DomainByName -Name $domainName
    if (-not $domain) {
        Write-Host "  FAIL domain not found: $domainName" -ForegroundColor Red
        $failed += $group.Count
        continue
    }

    foreach ($spec in $group.Group) {
        try {
            $ok = New-SubdomainDataProduct -Spec $spec -Domain $domain -ExistingByName $existingByName -DefaultContactId $defaultContactId
            if ($ok) {
                $created++
                $existingByName[$spec.name] = @{ name = $spec.name }
            }
        } catch {
            $failed++
            Write-Host "  FAIL create $($spec.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Created: $created"
Write-Host "Failed:  $failed"