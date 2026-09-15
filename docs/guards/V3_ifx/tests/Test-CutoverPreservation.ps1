$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$required = @(
    'mcp/LayerGuard/LayerGuard.slnx',
    'mcp/LayerGuard/baselines/b0.5.json',
    'mcp/LayerGuard/baselines/b1.json',
    'mcp/LayerGuard/baselines/b2.json',
    'mcp/LayerGuard/baselines/b3.json',
    'mcp/LayerGuard/baselines/b4.json',
    'mcp/LayerGuard/baselines/plan05.json',
    'mcp/LayerGuard/baselines/plan06.json',
    'mcp/LayerGuard/baselines/plan07.json',
    'docs/guards/V3',
    'docs/guards/V3_backup',
    'docs/guards/V3_ifx',
    'docs/guards/plans/05-v3-ifx-ci-cutover-and-legacy-cleanup.md',
    'docs/architecture/review/gates/G03/contract-event-catalog.yaml',
    'deployment/g04/release-runtime-manifest.json',
    'docs/architecture/review/gates/G05/context-protocol-v1.json'
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
if ($missing.Count -gt 0) { throw "Cutover preservation paths are missing: $($missing -join ', ')" }
$baselines = @(Get-ChildItem -LiteralPath (Join-Path $root 'mcp/LayerGuard/baselines') -Filter '*.json' -File)
if ($baselines.Count -ne 8) { throw "Expected eight preserved LayerGuard baselines, found $($baselines.Count)." }
Write-Host "Cutover preservation passed: $($required.Count) required paths and $($baselines.Count) historical baselines."
