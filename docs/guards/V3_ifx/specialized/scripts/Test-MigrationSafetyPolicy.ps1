[CmdletBinding()]
param(
    [string] $ReportPath = "artifacts/database-migrator/migration-safety-report.json",
    [switch] $NoBuild,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Debug'
)

$ErrorActionPreference = "Stop"
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
$policyPath = Join-Path $repositoryRoot "deployment/migration-safety-policy.json"
$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$outputRoot = Split-Path -Parent $resolvedReportPath
$inventoryPath = Join-Path $outputRoot 'G02-database-inventory.json'
$manifestPath = Join-Path $outputRoot 'G02-migration-manifest.json'
$inventoryGenerator = Join-Path $PSScriptRoot "Invoke-G02DatabaseInventory.ps1"
$generatorParameters = @{ ReportPath = $inventoryPath; ManifestPath = $manifestPath; Configuration = $Configuration }
if ($NoBuild) { $generatorParameters.NoBuild = $true }
& $inventoryGenerator @generatorParameters
if ($LASTEXITCODE -ne 0) { throw "Database inventory generation failed with exit code $LASTEXITCODE." }

$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -Depth 100
$failures = [System.Collections.Generic.List[string]]::new()
if ($policy.formatVersion -ne 1) { $failures.Add("Unsupported migration safety policy format.") }
if ($policy.defaultStrategy -ne "roll-forward") { $failures.Add("Default recovery strategy must be roll-forward.") }
if ($policy.automaticDownAllowed -ne $false) { $failures.Add("Automatic Down must remain disabled.") }

$risky = @(
    foreach ($module in $inventory.modules) {
        foreach ($migration in $module.Migrations) {
            if ($migration.Risk.Level -eq "high") {
                [pscustomobject]@{
                    module = $module.Module
                    migrationId = $migration.MigrationId
                    sourceSha256 = $migration.SourceSha256
                    signals = @($migration.Risk.Signals)
                }
            }
        }
    }
)

foreach ($migration in $risky) {
    $matches = @($policy.reviewedMigrations | Where-Object {
        $_.module -eq $migration.module -and $_.migrationId -eq $migration.migrationId
    })
    if ($matches.Count -ne 1) {
        $failures.Add("$($migration.module)/$($migration.migrationId) must have exactly one safety review entry.")
        continue
    }
    $review = $matches[0]
    if ($review.sourceSha256 -ne $migration.sourceSha256) {
        $failures.Add("$($migration.module)/$($migration.migrationId) review hash does not match its source.")
    }
    foreach ($signal in $migration.signals) {
        if ($signal -notin @($review.signals)) {
            $failures.Add("$($migration.module)/$($migration.migrationId) is missing review signal '$signal'.")
        }
    }
    if ($review.disposition -notin @("pre-gate-baseline", "approved")) {
        $failures.Add("$($migration.module)/$($migration.migrationId) has invalid review disposition.")
    }
    if ($review.disposition -eq "approved") {
        if ([string]::IsNullOrWhiteSpace($review.approvals.architecture) -or
            [string]::IsNullOrWhiteSpace($review.approvals.database) -or
            $review.restorePointRequired -ne $true -or
            [string]::IsNullOrWhiteSpace($review.dataLossAssessment)) {
            $failures.Add("$($migration.module)/$($migration.migrationId) lacks mandatory approval/recovery fields.")
        }
    }
}

$report = [ordered]@{
    formatVersion = 1
    gate = "G02"
    phase = 6
    result = if ($failures.Count -eq 0) { "passed" } else { "failed" }
    defaultStrategy = $policy.defaultStrategy
    automaticDownAllowed = $policy.automaticDownAllowed
    riskyMigrations = $risky.Count
    reviewedRiskyMigrations = @($policy.reviewedMigrations).Count
    failures = $failures
}
$reportDirectory = Split-Path -Parent $resolvedReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne "passed") { throw "Migration safety policy failed. Report: $resolvedReportPath" }
Write-Host "Migration safety policy passed. Report: $resolvedReportPath"
