param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$DomainId = "9499d5ed-3431-4618-b401-5fc0313bdca6",
    [string]$OwnerId = "6617cad6-d329-4361-951a-9eacbbaa8049"
)

$ErrorActionPreference = "Stop"

$baseUrl = "https://$PurviewAccount.purview.azure.com"
$apiVersion = "2026-03-20-preview"

$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
if (-not $token) {
    throw "Unable to get access token. Run az login and retry."
}

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Get-DomainTerms {
    param([string]$DomainId)
    return (Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/terms?api-version=$apiVersion&domainId=$DomainId&top=1000" -Headers $headers -Method Get).value
}

function Get-DomainCdes {
    param([string]$DomainId)
    return (Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/criticalDataElements?api-version=$apiVersion&domainId=$DomainId&top=1000" -Headers $headers -Method Get).value
}

function New-CdeIfMissing {
    param(
        [hashtable]$Spec,
        [hashtable]$ExistingByName
    )

    $key = $Spec.name.ToLower()
    if ($ExistingByName.ContainsKey($key)) {
        Write-Host "  SKIP CDE exists: $($Spec.name)" -ForegroundColor DarkYellow
        return $ExistingByName[$key]
    }

    $payload = @{
        name = $Spec.name
        description = $Spec.description
        status = "Published"
        domain = $DomainId
        dataType = "Text"
        contacts = @{
            owner = @(
                @{ id = $OwnerId }
            )
        }
    } | ConvertTo-Json -Depth 10

    $r = Invoke-WebRequest -Uri "$baseUrl/datagovernance/catalog/criticalDataElements?api-version=$apiVersion" -Headers $headers -Method Post -Body $payload -SkipHttpErrorCheck
    $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }

    if ($r.StatusCode -in 200, 201) {
        $created = $content | ConvertFrom-Json
        Write-Host "  OK CDE created: $($Spec.name) :: $($created.id)" -ForegroundColor Green
        $ExistingByName[$key] = $created
        return $created
    }

    throw "Failed creating CDE '$($Spec.name)' :: HTTP $($r.StatusCode) :: $content"
}

function Add-Relationship {
    param(
        [string]$ParentPath,
        [ValidateSet("Term", "CriticalDataElement", "DataAsset", "DataProduct")][string]$EntityType,
        [string]$TargetId,
        [string]$RelationshipType = "Related"
    )

    $body = @{ relationshipType = $RelationshipType; entityId = $TargetId } | ConvertTo-Json -Compress
    $uri = "$baseUrl/datagovernance/catalog/$ParentPath/relationships?entityType=$EntityType&api-version=$apiVersion"
    $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body $body -SkipHttpErrorCheck
    $content = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }

    if ($r.StatusCode -in 200, 201, 409) {
        return @{ ok = $true; status = $r.StatusCode; body = $content }
    }

    return @{ ok = $false; status = $r.StatusCode; body = $content }
}

Write-Host "=== Enrich Commercial Analytics lineage ===" -ForegroundColor Cyan
Write-Host "Domain: $DomainId"

$termList = Get-DomainTerms -DomainId $DomainId
$termsByName = @{}
foreach ($t in $termList) {
    if ($t.name) { $termsByName[$t.name.ToLower()] = $t }
}

Write-Host "Terms loaded in domain: $($termList.Count)"

$cdeSpecs = @(
    @{ name = "Pipeline Conversion Rate"; description = "Percentage of leads converted to opportunities and won deals." },
    @{ name = "Discount Leakage"; description = "Revenue loss from discounts outside approved pricing policy." },
    @{ name = "Forecast Accuracy"; description = "Variance between forecasted and actual revenue at period close." },
    @{ name = "Sell-out Volume"; description = "Units sold out to end customers by region and channel." },
    @{ name = "Data Freshness SLA"; description = "Expected refresh interval and compliance level for commercial datasets." },
    @{ name = "DQ Rule Pass Rate"; description = "Share of executed data quality rules passing for commercial assets." }
)

$existingCdes = Get-DomainCdes -DomainId $DomainId
$cdesByName = @{}
foreach ($c in $existingCdes) {
    if ($c.name) { $cdesByName[$c.name.ToLower()] = $c }
}

Write-Host "CDE loaded in domain: $($existingCdes.Count)"

$createdCdes = 0
foreach ($spec in $cdeSpecs) {
    $key = $spec.name.ToLower()
    if (-not $cdesByName.ContainsKey($key)) {
        $null = New-CdeIfMissing -Spec $spec -ExistingByName $cdesByName
        $createdCdes++
    } else {
        Write-Host "  SKIP CDE exists: $($spec.name)" -ForegroundColor DarkYellow
    }
}

# Refresh map after creates.
$existingCdes = Get-DomainCdes -DomainId $DomainId
$cdesByName = @{}
foreach ($c in $existingCdes) {
    if ($c.name) { $cdesByName[$c.name.ToLower()] = $c }
}

$cdeToTerm = @(
    @{ cde = "Pipeline Conversion Rate"; term = "Sales Pipeline" },
    @{ cde = "Discount Leakage"; term = "Pricing and Discount Effectiveness" },
    @{ cde = "Forecast Accuracy"; term = "Sales Pipeline" },
    @{ cde = "Sell-out Volume"; term = "Sales Pipeline" },
    @{ cde = "Data Freshness SLA"; term = "Data Freshness" },
    @{ cde = "DQ Rule Pass Rate"; term = "Data Quality Score" },
    @{ cde = "Pipeline Conversion Rate"; term = "DQ_Gold" },
    @{ cde = "Discount Leakage"; term = "DQ_Silver" },
    @{ cde = "Forecast Accuracy"; term = "DQ_Gold" },
    @{ cde = "Sell-out Volume"; term = "DQ_Silver" },
    @{ cde = "Data Freshness SLA"; term = "DQ_Bronze" },
    @{ cde = "DQ Rule Pass Rate"; term = "DQ_Gold" }
)

$termToTerm = @(
    @{ a = "Data Quality Score"; b = "Sales Pipeline" },
    @{ a = "Data Freshness"; b = "Sales Pipeline" },
    @{ a = "Data Quality Rule Coverage"; b = "Data Quality Score" },
    @{ a = "DQ_Gold"; b = "Data Quality Score" },
    @{ a = "DQ_Silver"; b = "Data Quality Score" },
    @{ a = "DQ_Bronze"; b = "Data Quality Score" },
    @{ a = "Data Accuracy"; b = "Data Quality Score" },
    @{ a = "Data Completeness"; b = "Data Quality Score" },
    @{ a = "Data Consistency"; b = "Data Quality Score" },
    @{ a = "Data Validity"; b = "Data Quality Score" }
)

$cdeTermOk = 0
$cdeTermFail = 0
foreach ($link in $cdeToTerm) {
    $cde = $cdesByName[$link.cde.ToLower()]
    $term = $termsByName[$link.term.ToLower()]
    if (-not $cde -or -not $term) {
        Write-Host "  SKIP CDE->Term missing: CDE='$($link.cde)' Term='$($link.term)'" -ForegroundColor Yellow
        continue
    }

    $r = Add-Relationship -ParentPath "criticalDataElements/$($cde.id)" -EntityType "Term" -TargetId $term.id -RelationshipType "Related"
    if ($r.ok) {
        $cdeTermOk++
        Write-Host "  OK CDE->Term: $($link.cde) -> $($link.term)" -ForegroundColor Green
    } else {
        $cdeTermFail++
        Write-Host "  FAIL CDE->Term: $($link.cde) -> $($link.term) :: HTTP $($r.status)" -ForegroundColor Red
    }
}

$termTermOk = 0
$termTermFail = 0
foreach ($link in $termToTerm) {
    $a = $termsByName[$link.a.ToLower()]
    $b = $termsByName[$link.b.ToLower()]
    if (-not $a -or -not $b) {
        Write-Host "  SKIP Term->Term missing: '$($link.a)' -> '$($link.b)'" -ForegroundColor Yellow
        continue
    }

    $r = Add-Relationship -ParentPath "terms/$($a.id)" -EntityType "Term" -TargetId $b.id -RelationshipType "Related"
    if ($r.ok) {
        $termTermOk++
        Write-Host "  OK Term->Term: $($link.a) -> $($link.b)" -ForegroundColor Cyan
    } else {
        $termTermFail++
        Write-Host "  FAIL Term->Term: $($link.a) -> $($link.b) :: HTTP $($r.status)" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "CDE created:       $createdCdes"
Write-Host "CDE->Term links:   $cdeTermOk ok / $cdeTermFail fail"
Write-Host "Term->Term links:  $termTermOk ok / $termTermFail fail"
