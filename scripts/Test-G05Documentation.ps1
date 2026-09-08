[CmdletBinding()]
param([string] $ReportPath = 'docs/architecture/review/evidence/gates/G05/G05-phase10-documentation-report.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { Join-Path $repositoryRoot $path }
$zhPath = Repo 'docs/architecture/review/gates/G05/context-sensitive-data-boundary.zh-CN.md'
$enPath = Repo 'docs/architecture/review/gates/G05/context-sensitive-data-boundary.en.md'
$zh = Get-Content -Raw -LiteralPath $zhPath
$en = Get-Content -Raw -LiteralPath $enPath
$diagramDirectory = Repo 'docs/architecture/review/gates/G05/diagrams'
$sources = @(Get-ChildItem -LiteralPath $diagramDirectory -Filter '*.mmd')
$zhDecisions = @([regex]::Matches($zh, 'G05-D\d{2}') | ForEach-Object Value | Select-Object -Unique | Sort-Object)
$enDecisions = @([regex]::Matches($en, 'G05-D\d{2}') | ForEach-Object Value | Select-Object -Unique | Sort-Object)
$rendered = @($sources | Where-Object {
    (Test-Path ([IO.Path]::ChangeExtension($_.FullName, 'svg'))) -and
    (Test-Path ([IO.Path]::ChangeExtension($_.FullName, 'png'))) -and
    (Get-Item ([IO.Path]::ChangeExtension($_.FullName, 'svg'))).Length -gt 1000 -and
    (Get-Item ([IO.Path]::ChangeExtension($_.FullName, 'png'))).Length -gt 1000
})
$backlinkPlans = @('01-contracts-adapters-refactor.md', '02-reliable-integration-events.md', '03-layerguard-alignment.md')
$checks = [ordered]@{
    bilingualDocumentsExist = (Test-Path $zhPath) -and (Test-Path $enPath)
    decisionIdsConsistent = ($zhDecisions -join ',') -eq ($enDecisions -join ',') -and $zhDecisions.Count -eq 10
    terminologyAndLifecycleTablesExist = ($zh -match '术语与生命周期') -and ($en -match 'Terminology and lifecycle') -and ($zh -match '禁止替代') -and ($en -match 'Forbidden substitutions')
    allSixDiagramSourcesRendered = $sources.Count -eq 6 -and $rendered.Count -eq 6
    requiredFlowsAreDocumented = @('current-context-boundary', 'target-context-boundary', 'http-contract-flow', 'event-context-flow', 'tenant-trust-decision', 'failure-replay-state' | Where-Object { $zh -notmatch $_ -or $en -notmatch $_ }).Count -eq 0
    classificationAdmissionMatrixExists = ($zh -match 'C0-C4 准入矩阵') -and ($en -match 'C0-C4 admission matrix')
    ruleMappingPresent = ($zh -match '规则到验证机制') -and ($en -match 'Rule-to-verification mapping')
    preReadyScopeExplicit = ($zh -match 'PRE-READY') -and ($en -match 'PRE-READY') -and ($zh -match 'Plan 01/02') -and ($en -match 'Plan 01/02')
    architectureIndexesLinkG05 = (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/index.md')) -match 'context-sensitive-data-boundary\.zh-CN\.md' -and (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/README.md')) -match 'context-sensitive-data-boundary\.zh-CN\.md'
    prerequisiteAndMasterLinkG05 = (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-prerequisites.md')) -match 'context-sensitive-data-boundary\.zh-CN\.md' -and (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-master-plan.md')) -match 'context-sensitive-data-boundary\.zh-CN\.md'
    downstreamPlansLinkBack = @($backlinkPlans | Where-Object { (Get-Content -Raw -LiteralPath (Repo "docs/architecture/review/plans/$_")) -notmatch 'G05 反向链接' }).Count -eq 0
}
$report = [ordered]@{ formatVersion=1; gate='G05'; phase=10; result=if($checks.Values -contains $false){'failed'}else{'passed'}; mermaidCliVersion='11.17.0'; checks=$checks }
$resolved = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Repo $ReportPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G05 documentation validation failed: $resolved" }
Write-Host "G05 documentation validation passed: $resolved"
