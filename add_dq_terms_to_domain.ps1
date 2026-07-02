param(
    [string]$PurviewAccount = "pdedemopurv",
    [string]$DomainId = "9499d5ed-3431-4618-b401-5fc0313bdca6"
)

$ErrorActionPreference = "Stop"

$baseUrl = "https://$PurviewAccount.purview.azure.com"
$apiVersion = "2026-03-20-preview"

$token = az account get-access-token --resource "https://purview.azure.net" --query accessToken -o tsv
if (-not $token) {
    throw "Unable to get access token. Run 'az login' and retry."
}

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

Write-Host "=== Add Data Quality terms to domain ===" -ForegroundColor Cyan
Write-Host "Domain: $DomainId"

$existingTerms = (Invoke-RestMethod -Uri "$baseUrl/datagovernance/catalog/terms?api-version=$apiVersion&domainId=$DomainId&top=1000" -Headers $headers -Method Get).value
$existingByName = @{}
foreach ($term in $existingTerms) {
    if ($term.name) {
        $existingByName[$term.name.ToLower()] = $term
    }
}

$dqTerms = @(
    @{ name = "Data Quality Score"; description = "Composite metric (accuracy, completeness, consistency, timeliness) used to assess dataset trustworthiness." },
    @{ name = "DQ_Gold"; description = "Data quality tier for high-confidence assets (score 90-100, critical checks passing)." },
    @{ name = "DQ_Silver"; description = "Data quality tier for acceptable assets (score 75-89, minor issues)." },
    @{ name = "DQ_Bronze"; description = "Data quality tier for assets with known issues or limited validation coverage (score below 75)." },
    @{ name = "Data Completeness"; description = "Degree to which required fields are present and populated." },
    @{ name = "Data Accuracy"; description = "Degree to which data correctly represents real-world values." },
    @{ name = "Data Consistency"; description = "Degree to which data values are aligned across systems and over time." },
    @{ name = "Data Freshness"; description = "Recency of data relative to expected update frequency and SLAs." },
    @{ name = "Data Validity"; description = "Conformance of data to expected formats, ranges, and business rules." },
    @{ name = "Data Quality Rule Coverage"; description = "Percentage of critical datasets and columns covered by active DQ checks." }
)

$created = 0
$skipped = 0
$failed = 0

foreach ($spec in $dqTerms) {
    $key = $spec.name.ToLower()
    if ($existingByName.ContainsKey($key)) {
        $skipped++
        Write-Host "  SKIP exists: $($spec.name)" -ForegroundColor DarkYellow
        continue
    }

    try {
        $payload = @{
            name = $spec.name
            description = $spec.description
            status = "Published"
            domain = $DomainId
        } | ConvertTo-Json -Depth 6

        $r = Invoke-WebRequest -Uri "$baseUrl/datagovernance/catalog/terms?api-version=$apiVersion" -Headers $headers -Method Post -Body $payload -SkipHttpErrorCheck
        if ($r.StatusCode -in 200, 201) {
            $createdTerm = $r.Content | ConvertFrom-Json
            $created++
            $existingByName[$key] = $createdTerm
            Write-Host "  OK created: $($spec.name) :: $($createdTerm.id)" -ForegroundColor Green
        } else {
            $failed++
            Write-Host "  FAIL create $($spec.name) :: HTTP $($r.StatusCode)" -ForegroundColor Red
            if ($r.Content) { Write-Host "    $($r.Content)" }
        }
    } catch {
        $failed++
        Write-Host "  FAIL create $($spec.name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Created: $created"
Write-Host "Skipped: $skipped"
Write-Host "Failed:  $failed"
