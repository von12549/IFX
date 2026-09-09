[CmdletBinding()]
param(
    [string] $OutputDirectory = 'artifacts/g04',
    [switch] $SkipRestore
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

if (-not $SkipRestore) {
    & dotnet restore (Join-Path $repositoryRoot 'IFX.sln')
    if ($LASTEXITCODE -ne 0) { throw 'G04 solution restore failed.' }
}

& (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeGuard.ps1') -Phase 10 -ReportPath (Join-Path $resolvedOutput 'guard.json')
& (Join-Path $PSScriptRoot 'Test-G04ReleaseOrchestration.ps1') -ReportPath (Join-Path $resolvedOutput 'orchestration.json')
& (Join-Path $PSScriptRoot 'Test-G04FailureMatrix.ps1') -ReportPath (Join-Path $resolvedOutput 'failure-matrix.json')
& (Join-Path $PSScriptRoot 'Test-Plan02C1InboundConformance.ps1') -ReportPath (Join-Path $resolvedOutput 'plan02-c1.json')
& (Join-Path $PSScriptRoot 'Invoke-LayerGuard.ps1') -ReportPath (Join-Path $resolvedOutput 'layerguard.json')

& dotnet build (Join-Path $repositoryRoot 'IFX.sln') --no-restore
if ($LASTEXITCODE -ne 0) { throw 'G04 solution build failed.' }
& dotnet test (Join-Path $repositoryRoot 'IFX.sln') --no-build --no-restore
if ($LASTEXITCODE -ne 0) { throw 'G04 solution tests failed.' }

$summary = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    phase = 10
    result = 'passed'
    scope = 'repository-automation-no-production-claim'
    completedAt = [DateTimeOffset]::UtcNow.ToString('O')
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedOutput 'verification-summary.json') -Encoding utf8NoBOM
Write-Host "G04 verification passed: $resolvedOutput"
