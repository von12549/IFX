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
    'docs/guards/V3_ifx',
    'docs/guards/plans/05-v3-ifx-ci-cutover-and-legacy-cleanup.md',
    'docs/guards/V3_ifx/stages/analysis/evidence/legacy-deletion-manifest.json',
    'docs/architecture/review/gates/G03/contract-event-catalog.yaml',
    'deployment/g04/release-runtime-manifest.json',
    'docs/architecture/review/gates/G05/context-protocol-v1.json'
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
if ($missing.Count -gt 0) { throw "Cutover preservation paths are missing: $($missing -join ', ')" }
$baselines = @(Get-ChildItem -LiteralPath (Join-Path $root 'mcp/LayerGuard/baselines') -Filter '*.json' -File)
if ($baselines.Count -ne 8) { throw "Expected eight preserved LayerGuard baselines, found $($baselines.Count)." }
$deletionManifest = Get-Content -Raw -LiteralPath (Join-Path $root 'docs/guards/V3_ifx/stages/analysis/evidence/legacy-deletion-manifest.json') | ConvertFrom-Json
$remaining = @($deletionManifest.deletedPaths | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) })
if ($remaining.Count -gt 0) { throw "Retired guard paths remain: $($remaining -join ', ')" }
$backupPresent = Test-Path -LiteralPath (Join-Path $root 'docs/guards/V3_backup')
$system = Get-Content -Raw -LiteralPath (Join-Path $root 'docs/guards/V3_ifx/guard-system.json') | ConvertFrom-Json
$backupCompatibility = @($system.compatibility.entries | Where-Object { $_.legacyPath -eq 'docs/guards/V3_backup' })
if ($backupPresent -and $backupCompatibility.Count -ne 1) { throw 'V3_backup exists but its transitional compatibility entry is missing.' }
if (-not $backupPresent -and $backupCompatibility.Count -ne 0) { throw 'V3_backup is retired but its compatibility entry remains.' }
$topLevel = @(Get-ChildItem -LiteralPath (Join-Path $root 'docs/guards') -Force | ForEach-Object Name | Sort-Object)
$expectedTopLevel = @('plans', 'V3', 'V3_ifx') + $(if ($backupPresent) { 'V3_backup' }) | Sort-Object
if (@(Compare-Object $expectedTopLevel $topLevel).Count -ne 0) {
    throw "docs/guards top level contains an unexpected entry: $($topLevel -join ', ')"
}
$v3Workflow = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/v3-ifx-guardrails.yml')
foreach ($trigger in @('pull_request', 'push', 'workflow_dispatch')) {
    if ($v3Workflow -notmatch "(?m)^  ${trigger}:") { throw "V3 workflow is missing its $trigger trigger." }
}
Write-Host "Cutover preservation passed: $($required.Count) required paths, $($baselines.Count) historical baselines, $($deletionManifest.deletedPaths.Count) retired paths absent, V3_backup transition consistent and one V3 workflow active."
