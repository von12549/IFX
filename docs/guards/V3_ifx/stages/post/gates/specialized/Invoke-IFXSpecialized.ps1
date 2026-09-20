[CmdletBinding()]
param(
    [ValidateSet('G03','G04','G05','Plan04','Database','All')]
    [string] $Gate = 'All',
    [string] $OutputDirectory = 'artifacts/guards/v3-ifx/specialized',
    [switch] $NoBuild,
    [string] $TargetRoot
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } elseif ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../..')) }
# Detector scripts read the target through GUARD_TARGET_ROOT; their code and package configuration stay in this package.
$previousTargetRoot = $env:GUARD_TARGET_ROOT
$env:GUARD_TARGET_ROOT = $repositoryRoot
$scriptRoot = Join-Path $PSScriptRoot 'scripts'
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$selected = if ($Gate -eq 'All') { @('G03','G04','G05','Plan04','Database') } else { @($Gate) }
$results = @()
foreach ($gateId in $selected) {
    $gateOutput = Join-Path $resolvedOutput $gateId.ToLowerInvariant()
    New-Item -ItemType Directory -Force -Path $gateOutput | Out-Null
    try {
        switch ($gateId) {
            'G03' {
                & (Join-Path $scriptRoot 'Invoke-G03ContractEventGuard.ps1') -Phase 9 -ReportPath (Join-Path $gateOutput 'guard.json')
            }
            'G04' {
                & (Join-Path $scriptRoot 'Invoke-G04Verification.ps1') -OutputDirectory $gateOutput
            }
            'G05' {
                & (Join-Path $scriptRoot 'Invoke-G05Verification.ps1') -OutputDirectory $gateOutput
            }
            'Plan04' {
                & (Join-Path $scriptRoot 'Test-Plan04Governance.ps1') -OutputDirectory $gateOutput
            }
            'Database' {
                $databaseTests = Join-Path $repositoryRoot 'tests/IFX.DatabaseBoundary.Tests/IFX.DatabaseBoundary.Tests.csproj'
                $databaseInventory = Join-Path $repositoryRoot 'tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj'
                $apiHost = Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj'
                $migrator = Join-Path $repositoryRoot 'src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj'
                if (-not $NoBuild) {
                    foreach ($project in @($databaseTests, $databaseInventory, $apiHost)) {
                        & dotnet restore $project
                        if ($LASTEXITCODE -ne 0) { throw "Database project restore failed: $project" }
                        & dotnet build $project --configuration Release --no-restore
                        if ($LASTEXITCODE -ne 0) { throw "Database project build failed: $project" }
                    }
                }
                $migrationArguments = @{ ReportPath = (Join-Path $gateOutput 'migration-safety.json'); Configuration = 'Release'; NoBuild = $true }
                $pendingArguments = @{ Configuration = 'Release'; NoBuild = $true }
                & (Join-Path $scriptRoot 'Test-MigrationSafetyPolicy.ps1') @migrationArguments
                & (Join-Path $scriptRoot 'Test-DatabasePendingModelChanges.ps1') @pendingArguments
                & (Join-Path $scriptRoot 'New-DatabaseMigrationArtifacts.ps1') -OutputDirectory (Join-Path $gateOutput 'release') -Configuration Release -NoBuild
                & dotnet publish $migrator --configuration Release --no-restore --output (Join-Path $gateOutput 'publish') /p:UseAppHost=false
                if ($LASTEXITCODE -ne 0) { throw 'DatabaseMigrator publish failed.' }
                & dotnet test $databaseTests --configuration Release --no-build --no-restore --filter 'FullyQualifiedName!~SqlServerMigrationMatrixTests'
                if ($LASTEXITCODE -ne 0) { throw 'Deterministic database boundary tests failed.' }
                & dotnet test $databaseTests --configuration Release --no-build --no-restore --filter 'FullyQualifiedName~SqlServerMigrationMatrixTests'
                if ($LASTEXITCODE -ne 0) { throw 'SQL Server migration matrix failed.' }
                [ordered]@{ formatVersion = 1; gate = 'Database'; result = 'passed'; checks = [ordered]@{ migrationSafety = $true; pendingModelChanges = $true; releaseArtifacts = $true; publish = $true; boundaryTests = $true; sqlServerMatrix = $true } } |
                    ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $gateOutput 'verification-summary.json') -Encoding utf8NoBOM
            }
        }
        $resultPath = switch ($gateId) {
            'G03' { Join-Path $gateOutput 'guard.json' }
            default { Join-Path $gateOutput 'verification-summary.json' }
        }
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw "$gateId did not produce its detector result." }
        if (-not (Test-Json -Path $resultPath -SchemaFile (Join-Path $PSScriptRoot 'contracts/detector-result.schema.json') -ErrorAction Stop)) { throw "$gateId detector result does not match its contract." }
        $results += [ordered]@{ id = $gateId; status = 'pass'; output = [IO.Path]::GetRelativePath($resolvedOutput, $gateOutput).Replace('\','/') }
    } catch {
        $results += [ordered]@{ id = $gateId; status = 'fail'; output = [IO.Path]::GetRelativePath($resolvedOutput, $gateOutput).Replace('\','/'); message = $_.Exception.Message }
    }
}
$env:GUARD_TARGET_ROOT = $previousTargetRoot

$summary = [ordered]@{
    schemaVersion = 1
    mode = 'specialized'
    status = if (@($results | Where-Object status -eq 'fail').Count -eq 0) { 'pass' } else { 'fail' }
    checks = $results
}
$summaryPath = Join-Path $resolvedOutput 'summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.status -ne 'pass') { throw "IFX specialized guards failed: $summaryPath" }
Write-Host "IFX specialized guards passed: $summaryPath"
