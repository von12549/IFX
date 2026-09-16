[CmdletBinding()]
param([string] $OutputDirectory = 'artifacts/guards/v3-ifx/specialized/g04')

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$guardPath = Join-Path $resolvedOutput 'guard.json'
$inboundPath = Join-Path $resolvedOutput 'plan02-c1.json'
& (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeGuard.ps1') -Phase 12 -ReportPath $guardPath
& (Join-Path $PSScriptRoot 'Test-Plan02C1InboundConformance.ps1') -ReportPath $inboundPath

$guard = Get-Content -Raw -LiteralPath $guardPath | ConvertFrom-Json -Depth 100
$inbound = Get-Content -Raw -LiteralPath $inboundPath | ConvertFrom-Json -Depth 100
$checks = [ordered]@{
    deploymentRuntime = $guard.result -eq 'passed' -and $guard.phase -eq 12
    inboundConformance = $inbound.result -eq 'passed'
}
$summary = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    phase = 12
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    scope = 'specialized-runtime-policy-no-build-or-layerguard'
    checks = $checks
    reports = [ordered]@{ deploymentRuntime = 'guard.json'; inboundConformance = 'plan02-c1.json' }
}
$summaryPath = Join-Path $resolvedOutput 'verification-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.result -ne 'passed') { throw "G04 verification failed: $summaryPath" }
Write-Host "G04 specialized verification passed: $summaryPath"
