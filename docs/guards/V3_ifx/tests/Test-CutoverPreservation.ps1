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
$legacyWorkflows = @(
    '.github/workflows/coding-guardrails.yml',
    '.github/workflows/layerguard.yml',
    '.github/workflows/contract-event-governance.yml',
    '.github/workflows/g04-deployment-runtime.yml',
    '.github/workflows/g05-context-boundary.yml',
    '.github/workflows/plan04-governance.yml',
    '.github/workflows/database-migrations.yml'
)
foreach ($relativePath in $legacyWorkflows) {
    $workflow = Get-Content -Raw -LiteralPath (Join-Path $root $relativePath)
    if ($workflow -notmatch '(?m)^on:\r?\n  workflow_dispatch:\s*$') {
        throw "Legacy workflow must retain a manual workflow_dispatch trigger: $relativePath"
    }
    if ($workflow -match '(?m)^  (pull_request|push|schedule):') {
        throw "Legacy workflow must not have an automatic trigger: $relativePath"
    }
}
$v3Workflow = Get-Content -Raw -LiteralPath (Join-Path $root '.github/workflows/v3-ifx-guardrails.yml')
foreach ($trigger in @('pull_request', 'push', 'workflow_dispatch')) {
    if ($v3Workflow -notmatch "(?m)^  ${trigger}:") { throw "V3 workflow is missing its $trigger trigger." }
}
Write-Host "Cutover preservation passed: $($required.Count) required paths, $($baselines.Count) historical baselines and $($legacyWorkflows.Count) manual-only legacy workflows."
