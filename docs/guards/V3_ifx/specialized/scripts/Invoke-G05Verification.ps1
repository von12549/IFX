[CmdletBinding()]
param([string] $OutputDirectory = 'artifacts/guards/v3-ifx/specialized/g05')

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$contextPath = Join-Path $resolvedOutput 'context-boundary.json'
$securityPath = Join-Path $resolvedOutput 'security-boundary.json'
& (Join-Path $PSScriptRoot 'Invoke-G05ContextBoundaryGuard.ps1') -Phase 11 -ReportPath $contextPath
& (Join-Path $PSScriptRoot 'Test-Plan05SecurityBoundary.ps1') -ReportPath $securityPath

$context = Get-Content -Raw -LiteralPath $contextPath | ConvertFrom-Json -Depth 100
$security = Get-Content -Raw -LiteralPath $securityPath | ConvertFrom-Json -Depth 100
$checks = [ordered]@{
    contextBoundary = $context.result -eq 'passed' -and $context.phase -eq 11
    securityBoundary = $security.result -eq 'passed'
}
$summary = [ordered]@{
    formatVersion = 1
    gate = 'G05'
    phase = 11
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    scope = 'specialized-context-and-security-no-build-or-layerguard'
    checks = $checks
    reports = [ordered]@{ contextBoundary = 'context-boundary.json'; securityBoundary = 'security-boundary.json' }
}
$summaryPath = Join-Path $resolvedOutput 'verification-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.result -ne 'passed') { throw "G05 verification failed: $summaryPath" }
Write-Host "G05 specialized verification passed: $summaryPath"
