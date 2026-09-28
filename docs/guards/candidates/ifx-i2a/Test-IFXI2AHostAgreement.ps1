# IFX I2-A (Plan 20260929-v4-ifx-i2a-installed-webui) step A4: query the installed Host for the two Web UI runs and
# require exact agreement with the evidence projections the Web UI displayed (exported from its raw-JSON view).
[CmdletBinding()]
param(
    [string] $OutputRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/i2a-webui-044',
    [string] $RuntimeRoot = 'D:/IFX-Root/guard-runtime'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string] $Message) { throw $Message }
function Write-Json([string] $Path, $Value) {
    if (Test-Path -LiteralPath $Path) { Fail "Output already exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 60).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
$install = "$RuntimeRoot/releases/v4-guards-1.1.6-ifx-0.4.4"; $package = "$install/package"; $hostDll = "$install/host/v4-guards.dll"
$state = "$RuntimeRoot/state/ifx-i2a-044-webui"; $evidence = "$RuntimeRoot/evidence/ifx-i2a-044-webui"
function HostQuery([string[]] $QueryArgs) {
    $raw = @(& dotnet $hostDll @QueryArgs 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { Fail "Host query failed: $($QueryArgs -join ' '): $raw" }
    $raw | ConvertFrom-Json -Depth 60
}
function Canon($Value) { $Value | ConvertTo-Json -Depth 60 -Compress }
$cases = @(
    [ordered]@{ id = 'clean'; root = "$RuntimeRoot/fixtures/ifx-i1-clean-044"; ui = "$OutputRoot/ui-clean-raw.json"; expect = 'pass' },
    [ordered]@{ id = 'violating'; root = "$RuntimeRoot/fixtures/ifx-i1-violating-044"; ui = "$OutputRoot/ui-violating-raw.json"; expect = 'fail' }
)
$rows = [Collections.Generic.List[object]]::new()
foreach ($c in $cases) {
    # The Web UI export is the JSON text of its raw view, stored as a JSON string.
    $uiText = Get-Content -Raw -LiteralPath $c.ui | ConvertFrom-Json
    $ui = $uiText | ConvertFrom-Json -Depth 60
    $project = HostQuery @('query', 'project', '--package-root', $package, '--target-root', $c.root, '--state-root', $state, '--evidence-root', $evidence)
    $projectId = [string]$project.project.projectId
    if (-not [bool]$project.project.bound -or [string]$project.project.profileId -cne 'ifx_profile') { Fail "$($c.id): Host project is not bound to ifx_profile." }
    $runs = HostQuery @('query', 'runs', '--package-root', $package, '--state-root', $state, '--evidence-root', $evidence, '--project', $projectId)
    $runIds = @($runs.runs | ForEach-Object { [string]$_.runId })
    if ($runIds.Count -ne 1) { Fail "$($c.id): expected exactly one Host run, found $($runIds.Count)" }
    $ev = HostQuery @('query', 'evidence', '--package-root', $package, '--state-root', $state, '--evidence-root', $evidence, '--project', $projectId, '--run', $runIds[0])
    $result = $ev.stageResult
    $checks = [ordered]@{
        projectId = ([string]$ui.projectId -ceq $projectId)
        runId = ([string]$ui.runId -ceq $runIds[0])
        resultSha256 = ([string]$ui.resultSha256 -ceq [string]$ev.resultSha256)
        fullProjectionEqual = ((Canon $ui) -ceq (Canon $ev))
        verdict = ([string]$result.status -ceq $c.expect)
        moduleCount = (@($result.moduleResults).Count -eq 10)
        coverageNonVacuous = (@($result.coverage).Count -eq 22 -and @($result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0)
    }
    if ($c.id -ceq 'clean') {
        $checks.findings = (@($result.findings).Count -eq 0 -and [string]$result.exitCategory -ceq 'success')
    } else {
        $f = @($result.findings)
        $checks.findings = ($f.Count -eq 1 -and [string]$f[0].ruleId -ceq 'IMPORT-DIRECTION' -and [string]$f[0].detectorId -ceq 'ifx-source-policy' -and
            [string]$f[0].severity -ceq 'blocking' -and ([string]$f[0].subject).StartsWith('src/Modules/CRM/IFX.Modules.CRM.Domain/I1S7Fault.cs') -and [string]$result.exitCategory -ceq 'findings-blocking')
    }
    Write-Json "$OutputRoot/host-$($c.id)-project.json" $project
    Write-Json "$OutputRoot/host-$($c.id)-runs.json" $runs
    Write-Json "$OutputRoot/host-$($c.id)-evidence.json" $ev
    $rows.Add([ordered]@{ id = $c.id; projectId = $projectId; runId = $runIds[0]; resultSha256 = [string]$ev.resultSha256; status = [string]$result.status
        exitCategory = [string]$result.exitCategory; findingCount = @($result.findings).Count; coverageClaimCount = @($result.coverage).Count
        checks = $checks; pass = (@($checks.Values | Where-Object { -not $_ }).Count -eq 0) })
}
$status = if (@($rows | Where-Object { -not $_.pass }).Count -eq 0) { 'pass' } else { 'fail' }
Write-Json "$OutputRoot/host-agreement.json" ([ordered]@{ formatVersion = 1; step = 'A4'; status = $status; cases = @($rows.ToArray()) })
$rows | ForEach-Object { "{0}: run {1} {2}/{3} findings={4} coverage={5} pass={6}" -f $_.id, $_.runId, $_.status, $_.exitCategory, $_.findingCount, $_.coverageClaimCount, $_.pass }
if ($status -cne 'pass') { exit 1 }
