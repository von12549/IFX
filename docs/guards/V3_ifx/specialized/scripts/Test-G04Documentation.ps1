[CmdletBinding()]
param([string] $ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-phase11-documentation-report.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $repositoryRoot $path } }
$zhPath = Repo 'docs/architecture/review/gates/G04/deployment-runtime-boundary.zh-CN.md'
$enPath = Repo 'docs/architecture/review/gates/G04/deployment-runtime-boundary.en.md'
$zh = Get-Content -Raw -LiteralPath $zhPath
$en = Get-Content -Raw -LiteralPath $enPath
$diagramDirectory = Repo 'docs/architecture/review/gates/G04/diagrams'
$sources = @(Get-ChildItem -LiteralPath $diagramDirectory -Filter '*.mmd')
$zhDecisions = @([regex]::Matches($zh, 'G04-D\d{2}') | ForEach-Object Value | Select-Object -Unique | Sort-Object)
$enDecisions = @([regex]::Matches($en, 'G04-D\d{2}') | ForEach-Object Value | Select-Object -Unique | Sort-Object)
$rendered = @($sources | Where-Object {
    (Test-Path ([IO.Path]::ChangeExtension($_.FullName, 'svg'))) -and
    (Test-Path ([IO.Path]::ChangeExtension($_.FullName, 'png'))) -and
    (Get-Item ([IO.Path]::ChangeExtension($_.FullName, 'svg'))).Length -gt 1000 -and
    (Get-Item ([IO.Path]::ChangeExtension($_.FullName, 'png'))).Length -gt 1000
})
$checks = [ordered]@{
    bilingualDocumentsExist = (Test-Path $zhPath) -and (Test-Path $enPath)
    decisionIdsConsistent = ($zhDecisions -join ',') -eq ($enDecisions -join ',') -and $zhDecisions.Count -eq 9
    allSixDiagramSourcesRendered = $sources.Count -eq 6 -and $rendered.Count -eq 6
    ruleMappingPresent = ($zh -match '规则到验证机制') -and ($en -match 'Rule-to-verification mapping')
    preReadyScopeExplicit = ($zh -match 'PRE-READY') -and ($en -match 'PRE-READY') -and ($en -match 'E3/E4/E6')
    architectureIndexLinksG04 = (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/README.md')) -match 'deployment-runtime-boundary\.zh-CN\.md'
    prerequisiteLinksG04 = (Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-prerequisites.md')) -match 'deployment-runtime-boundary\.zh-CN\.md'
    downstreamPlansLinkBack = @('00-G02-database-boundary.md','01-contracts-adapters-refactor.md','02-reliable-integration-events.md','03-layerguard-alignment.md' | Where-Object {
        (Get-Content -Raw -LiteralPath (Repo "docs/architecture/review/plans/$_")) -notmatch 'G04 反向链接'
    }).Count -eq 0
}
$report = [ordered]@{ formatVersion=1; gate='G04'; phase=11; result=if($checks.Values -contains $false){'failed'}else{'passed'}; mermaidCliVersion='11.17.0'; checks=$checks }
$resolved = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 documentation validation failed: $resolved" }
Write-Host "G04 documentation validation passed: $resolved"
