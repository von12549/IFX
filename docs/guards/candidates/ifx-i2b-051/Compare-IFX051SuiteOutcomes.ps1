# IFX I2-B amendment A2 step A2-5: the catalog cases of the five 0.5.1 lock consumers, run on evidence from the relocated
# producers, against the accepted A1-3 records of the same modules run on evidence from the V3-wrapping producers (ruling
# R11: the violation fixtures fail the same way). Cases present in both must agree in kind, expectation, outcome and
# findings; cases added after A1-3 (A1-4, proven by the A1-6 C6c) must pass and are listed apart.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SuiteRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [string]$PredecessorRoot = 'artifacts/guards/p10-ifx-i2b/a1-suites'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathFullyQualified($OutputRoot)) { $OutputRoot } else { Join-Path $repo $OutputRoot }))
if (Test-Path -LiteralPath $output) { throw "OutputRoot must be absent: $output" }
[void][IO.Directory]::CreateDirectory($output)
function Field($c, [string]$Name) { if ($c.PSObject.Properties[$Name]) { $c.$Name } else { $null } }
function Shape($c) { [ordered]@{ kind = [string]$c.kind; expected = [string]$c.expected; actual = [string]$c.actual; pass = [bool]$c.pass; message = ([string](Field $c 'message')) -replace 'artifacts/guards/(p10-ifx-[a-z0-9-]+|v4a-producers)/[a-z]+-runs/[0-9a-f]{32}/', '<run>/'
    findings = @(@(Field $c 'findings') | Where-Object { $null -ne $_ } | ForEach-Object { "$(Field $_ 'ruleId')|$(Field $_ 'severity')" } | Sort-Object -Unique) } }
$modules = @('ifx-c1-type-provenance', 'ifx-solution-evidence', 'ifx-assembly-evidence', 'ifx-frontend-evidence', 'ifx-database-evidence')
$rows = foreach ($m in $modules) {
    $dirs = @(Get-ChildItem -LiteralPath $SuiteRoot -Directory -Filter "$m-*"); if ($dirs.Count -ne 1) { throw "Expected one suite run for $m" }
    $cur = Get-Content -LiteralPath (Join-Path $dirs[0].FullName 'summary.json') -Raw | ConvertFrom-Json -Depth 50
    $old = Get-Content -LiteralPath (Join-Path $repo "$PredecessorRoot/$m.summary.json") -Raw | ConvertFrom-Json -Depth 50
    $copy = Join-Path $output "$m.summary.json"; Copy-Item -LiteralPath (Join-Path $dirs[0].FullName 'summary.json') -Destination $copy
    $oldCases = @{}; foreach ($c in @($old.cases)) { $oldCases[[string]$c.id] = $c }
    $diffs = [Collections.Generic.List[object]]::new(); $added = [Collections.Generic.List[object]]::new()
    foreach ($c in @($cur.cases)) {
        if (-not $oldCases.ContainsKey([string]$c.id)) { $added.Add([ordered]@{ id = $c.id; kind = $c.kind; expected = $c.expected; actual = $c.actual; pass = [bool]$c.pass }); continue }
        $a = (Shape $oldCases[[string]$c.id]) | ConvertTo-Json -Compress -Depth 5; $b = (Shape $c) | ConvertTo-Json -Compress -Depth 5
        if ($a -cne $b) { $diffs.Add([ordered]@{ id = $c.id; a13 = $a; a25 = $b }) }
    }
    $missing = @($oldCases.Keys | Where-Object { $k = $_; @($cur.cases | Where-Object { [string]$_.id -ceq $k }).Count -eq 0 })
    [ordered]@{ moduleId = $m; version = $cur.version; status = $cur.status; cases = @($cur.cases).Count; failed = @($cur.cases | Where-Object { -not $_.pass }).Count
        predecessorVersion = $old.version; predecessorCases = @($old.cases).Count; commonCases = @($cur.cases).Count - $added.Count
        outcomeDifferences = @($diffs); casesAddedAfterA13 = @($added); casesMissing = $missing; host = $cur.host.status
        policySha256 = $cur.policySha256; summarySha256 = Get-IFX050Sha256 $copy; targetCommit = $cur.targetCommit }
}
$bad = @($rows | Where-Object { $_.status -cne 'pass' -or $_.failed -ne 0 -or @($_.outcomeDifferences).Count -ne 0 -or @($_.casesMissing).Count -ne 0 -or @($_.casesAddedAfterA13 | Where-Object { -not $_.pass }).Count -ne 0 })
$status = if ($bad.Count -eq 0) { 'pass' } else { 'fail' }
Write-IFX050Json (Join-Path $output 'index.json') ([ordered]@{ formatVersion = 1; kind = 'ifx-051-suite-outcomes'; step = 'A2-5'; status = $status
    rule = 'catalog cases common with A1-3 agree in kind, expectation, outcome and findings; cases added in A1-4 pass (R11)'
    modules = @($rows); caseTotal = ($rows | ForEach-Object { $_.cases } | Measure-Object -Sum).Sum })
Write-Output "A2-5 suite outcomes $status`: $(($rows | ForEach-Object { "$($_.moduleId) $($_.cases)/$($_.commonCases) common, $(@($_.outcomeDifferences).Count) diffs" }) -join '; ')"
if ($status -cne 'pass') { exit 1 }
