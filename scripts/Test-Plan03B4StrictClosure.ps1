[CmdletBinding()]
param(
    [string] $LayerGuardReportPath = 'docs/architecture/review/evidence/layerguard/B4-report.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/layerguard/B4-validation-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}

function Read-Json([string] $path) {
    $resolved = Resolve-RepoPath $path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Required B4 artifact is missing: $resolved"
    }
    Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json -Depth 100
}

$report = Read-Json $LayerGuardReportPath
$baseline = Read-Json 'mcp/LayerGuard/baselines/b4.json'
$b1 = Read-Json 'docs/architecture/review/evidence/layerguard/B1-report.json'
$b2 = Read-Json 'docs/architecture/review/evidence/layerguard/B2-report.json'
$b3 = Read-Json 'docs/architecture/review/evidence/layerguard/B3-report.json'
$graph = Read-Json 'docs/architecture/review/evidence/layerguard/B4-dependency-graph.json'
$configText = Get-Content -Raw -LiteralPath (Resolve-RepoPath 'src/layerguard.json')
$workflow = Get-Content -Raw -LiteralPath (Resolve-RepoPath '.github/workflows/layerguard.yml')

$legacyProjects = @(Get-ChildItem (Resolve-RepoPath 'src/Modules'), (Resolve-RepoPath 'src/Platform') -Recurse -File -Filter '*.csproj' |
    Where-Object { $_.BaseName -like '*.Abstractions' })
$legacyNamespaces = @(Get-ChildItem (Resolve-RepoPath 'src/Modules'), (Resolve-RepoPath 'src/Platform') -Recurse -File -Filter '*.cs' |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
    Select-String -Pattern 'IFX\.(Modules|Platform)\..*\.Abstractions')

$checks = [ordered]@{
    strictReportClean = $report.verdict -eq 'baseline-clean' -and $report.violationCount -eq 0 -and @($report.clusters).Count -eq 0
    emptyBaseline = @($baseline.entries).Count -eq 0 -and $report.baseline.totalEntries -eq 0 -and $report.baseline.matched -eq 0 -and $report.baseline.new -eq 0 -and $report.baseline.stale -eq 0
    rulesetBound = $baseline.rulesetHash -eq $report.ruleset.hash -and @($report.ruleset.policyBindings).Count -eq 12
    historicalReduction = $b1.violationCount -eq 116 -and $b2.violationCount -eq 103 -and $b3.violationCount -eq 32 -and $report.violationCount -eq 0
    compatibilityRemoved = $configText -notmatch 'IFX\.Modules\.\*\.Abstractions' -and $configText -notmatch 'IFX\.Platform\.\*\.Abstractions'
    legacySourceRemoved = $legacyProjects.Count -eq 0 -and $legacyNamespaces.Count -eq 0
    graphCaptured = $graph.scope.projectsInScope -eq $report.scope.projectsInScope -and $graph.scope.projectsInScope -eq 39
    ciStrict = $workflow -match 'Invoke-LayerGuard\.ps1 -ReportPath artifacts/layerguard/b4-ci\.json' -and $workflow -match 'Test-Plan03B4StrictClosure\.ps1'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = '03-layerguard-alignment'
    milestone = 'B4-strict'
    result = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    checks = $checks
    metrics = [ordered]@{
        b1Findings = $b1.violationCount
        b2Findings = $b2.violationCount
        b3Findings = $b3.violationCount
        b4Findings = $report.violationCount
        projectsInScope = $report.scope.projectsInScope
        baselineEntries = $report.baseline.totalEntries
    }
    failedChecks = $failed
    remainingScope = @('Architecture owner approval', 'Production-dependent final validation')
}

$resolvedStatus = Resolve-RepoPath $StatusPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedStatus) | Out-Null
$status | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM

if ($failed.Count -gt 0) {
    throw "Plan 03 B4 strict closure validation failed: $($failed -join ', '). Report: $resolvedStatus"
}

Write-Host "Plan 03 B4 strict closure validation passed: $resolvedStatus"
