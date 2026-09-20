[CmdletBinding()]
param()

# Positive and negative fixtures for ci/Invoke-IFXCiContract.ps1 (Plan 06 P1.3).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-ci-contract-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$verifier = Join-Path $package 'ci/Invoke-IFXCiContract.ps1'
$utf8 = [Text.UTF8Encoding]::new($false)
$workflowSource = [IO.File]::ReadAllText((Join-Path $repository '.github/workflows/v3-ifx-guardrails.yml')).Replace("`r`n", "`n")
$jobsSource = [IO.File]::ReadAllText((Join-Path $package 'ci/jobs.json')).Replace("`r`n", "`n")

function New-Ruleset([string[]] $contexts, [bool] $strict = $true, [string] $enforcement = 'active') {
    $declaration = $jobsSource | ConvertFrom-Json
    return [ordered]@{
        id = $declaration.ruleset.id; name = $declaration.ruleset.name; enforcement = $enforcement
        rules = @(
            [ordered]@{ type = 'deletion' },
            [ordered]@{ type = 'required_status_checks'; parameters = [ordered]@{ strict_required_status_checks_policy = $strict; required_status_checks = @($contexts | ForEach-Object { [ordered]@{ context = $_; integration_id = 15368 } }) } }
        )
    } | ConvertTo-Json -Depth 10
}
$allChecks = @(($jobsSource | ConvertFrom-Json).jobs | ForEach-Object { $_.id })

function Invoke-Case([string] $label, [int] $expected, [string] $workflow = $workflowSource, [string] $jobs = $jobsSource, [string] $ruleset, [string] $expectText) {
    $case = Join-Path $fixture ([Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory((Join-Path $case '.github/workflows'))
    [void][IO.Directory]::CreateDirectory((Join-Path $case 'docs/guards/V3_ifx/ci'))
    [IO.File]::WriteAllText((Join-Path $case '.github/workflows/v3-ifx-guardrails.yml'), $workflow, $utf8)
    [IO.File]::WriteAllText((Join-Path $case 'docs/guards/V3_ifx/ci/jobs.json'), $jobs, $utf8)
    $arguments = @('-NoProfile', '-File', $verifier, '-TargetRoot', $case, '-JobsPath', 'docs/guards/V3_ifx/ci/jobs.json')
    if ($ruleset) {
        [IO.File]::WriteAllText((Join-Path $case 'ruleset.json'), $ruleset, $utf8)
        $arguments += @('-RulesetJsonPath', 'ruleset.json')
    }
    $output = @(& pwsh @arguments 2>&1) -join ' | '
    if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
    if ($expectText -and -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not report '$expectText': $output" }
    Write-Host "PASS $label"
}

function Edit-MarkedBlock([string] $source, [string] $beginMarker, [string] $endMarker, [string] $oldValue, [string] $newValue) {
    $begin = $source.IndexOf($beginMarker, [StringComparison]::Ordinal)
    $end = if ($begin -ge 0) { $source.IndexOf($endMarker, $begin + $beginMarker.Length, [StringComparison]::Ordinal) } else { -1 }
    if ($begin -lt 0 -or $end -lt 0) { throw "Fixture could not find marked block $beginMarker ... $endMarker." }
    $block = $source.Substring($begin, ($end + $endMarker.Length) - $begin)
    $edited = $block.Replace($oldValue, $newValue)
    if ($edited -eq $block) { throw "Fixture could not edit '$oldValue' in $beginMarker." }
    return $source.Substring(0, $begin) + $edited + $source.Substring($end + $endMarker.Length)
}

try {
    Invoke-Case 'current workflow matches jobs.json' 0
    Invoke-Case 'matching ruleset passes' 0 -ruleset (New-Ruleset $allChecks)
    Invoke-Case 'renamed workflow check fails' 1 -workflow $workflowSource.Replace('    name: v3-quality-frontend', '    name: v3-quality-web') -expectText 'declaration-matches-workflow'
    Invoke-Case 'undeclared workflow job fails' 1 -jobs ($jobsSource -replace '(?m)^\s*\{ "id": "v3-specialized-g05".*\r?\n', '') -expectText 'declaration-matches-workflow'
    Invoke-Case 'wrong required count fails' 1 -jobs $jobsSource.Replace('"requiredCheckCount": 13', '"requiredCheckCount": 12') -expectText 'declaration-required-count'
    Invoke-Case 'trigger declaration mismatch fails' 1 -jobs $jobsSource.Replace('"id": "v3-historical-integrity", "mode": "historical-integrity", "trigger": "pull-request-and-main"', '"id": "v3-historical-integrity", "mode": "historical-integrity", "trigger": "pull-request"') -expectText 'declaration-trigger:v3-historical-integrity'
    Invoke-Case 'unknown trigger fails' 1 -jobs $jobsSource.Replace('"id": "v3-architecture", "mode": "architecture", "trigger": "pull-request-and-main"', '"id": "v3-architecture", "mode": "architecture", "trigger": "history-change-schedule-manual"') -expectText "unknown trigger"
    Invoke-Case 'non-blocking job fails' 1 -jobs $jobsSource.Replace('"id": "v3-quality-assembly", "mode": "quality", "gate": "assembly", "trigger": "pull-request-and-main", "blocking": true', '"id": "v3-quality-assembly", "mode": "quality", "gate": "assembly", "trigger": "pull-request-and-main", "blocking": false') -expectText 'declaration-blocking:v3-quality-assembly'
    Invoke-Case 'matrix expansion change fails' 1 -workflow $workflowSource.Replace('os: [ubuntu-latest, windows-latest]', 'os: [ubuntu-latest]') -expectText 'declaration-matches-workflow'
    Invoke-Case 'pull-request job without condition fails' 1 -workflow $workflowSource.Replace("    if: github.event_name == 'pull_request'`n", '') -expectText 'declaration-trigger:v3-pre-diff'
    Invoke-Case 'missing push trigger fails' 1 -workflow $workflowSource.Replace("  push:`n    branches: [main]`n", '') -expectText 'workflow-triggers'
    Invoke-Case 'ruleset missing a required context fails' 1 -ruleset (New-Ruleset @($allChecks | Where-Object { $_ -ne 'v3-quality-frontend' })) -expectText 'ruleset-contexts'
    Invoke-Case 'ruleset extra context fails' 1 -ruleset (New-Ruleset @($allChecks + 'legacy-guard')) -expectText 'ruleset-contexts'
    Invoke-Case 'ruleset without strict fails' 1 -ruleset (New-Ruleset $allChecks $false) -expectText 'ruleset-strict'
    Invoke-Case 'inactive ruleset fails' 1 -ruleset (New-Ruleset $allChecks $true 'evaluate') -expectText 'ruleset-active'
    Invoke-Case 'check without its trusted base gate fails' 1 -workflow $workflowSource.Replace('-GateId v3-historical-integrity', '-GateId v3-other') -expectText 'trusted-base-runner:v3-historical-integrity'
    Invoke-Case 'matrix check without its trusted base gate fails' 1 -workflow $workflowSource.Replace('-GateId v3-cross-platform-${{ matrix.os }}', '-GateId v3-cross-platform-ubuntu-latest') -expectText 'trusted-base-runner:v3-cross-platform-windows-latest'
    Invoke-Case 'head dispatcher run in place fails' 1 -workflow $workflowSource.Replace('-Mode HistoricalIntegrity -GateId v3-historical-integrity', "-Mode HistoricalIntegrity -GateId v3-historical-integrity`n          ./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode HistoricalIntegrity") -expectText 'trusted-base-no-head-dispatcher:v3-historical-integrity'
    Invoke-Case 'job without the base worktree fails' 1 -workflow ([Regex]::new('git worktree add --detach').Replace($workflowSource, 'git worktree list', 1)) -expectText 'trusted-base-worktree:v3-pre-diff'
    Invoke-Case 'aggregate plan selector removal fails' 1 -workflow $workflowSource.Replace("`$aggregatePlans = @(`$plans | Where-Object { `$_ -match '(?i)-aggregate\.plan\.json$' })", '`$aggregatePlans = @()') -expectText 'workflow-aggregate-plan-selection'
    # Plan 06 D28: cost controls and the base-owned change scope are declared in ci/jobs.json and enforced in the workflow.
    Invoke-Case 'missing concurrency fails' 1 -workflow ([Regex]::Replace($workflowSource, '(?m)^concurrency:\n(  .*\n)+', '')) -expectText 'cost-concurrency'
    Invoke-Case 'keeping superseded runs fails' 1 -workflow $workflowSource.Replace('  cancel-in-progress: true', '  cancel-in-progress: false') -expectText 'cost-concurrency'
    Invoke-Case 'undeclared schedule fails' 1 -workflow $workflowSource.Replace("    - cron: '17 3 1 * *'", "    - cron: '17 3 * * 1'") -expectText 'cost-schedule'
    Invoke-Case 'missing package cache fails' 1 -workflow ([Regex]::Replace($workflowSource, '(?m)^      - name: Cache reviewed guard packages\n(        .*\n|          .*\n)+', '', 1)) -expectText 'cost-package-cache:v3-architecture'
    Invoke-Case 'package cache not keyed by the reviewed locks fails' 1 -workflow $workflowSource.Replace("hashFiles('docs/guards/*/build/locks/*.packages.lock.json')", "github.sha") -expectText 'cost-package-cache:v3-architecture'
    $smokeWithoutBuild = Edit-MarkedBlock $workflowSource '# BEGIN WINDOWS PORTABILITY SMOKE' '# END WINDOWS PORTABILITY SMOKE' "              ,@('./docs/guards/V3/tests/Test-V3BuildBaseline.ps1')`n" ''
    Invoke-Case 'Windows smoke without the locked build baseline fails' 1 -workflow $smokeWithoutBuild -expectText 'cost-windows-smoke-commands'
    $fullWithoutTrustedBase = Edit-MarkedBlock $workflowSource '# BEGIN FULL CANDIDATE SUITE' '# END FULL CANDIDATE SUITE' "              ,@('./docs/guards/V3_ifx/tests/Test-IFXTrustedBase.ps1')" "              ,@('./docs/guards/V3_ifx/tests/Test-IFXPre.ps1')"
    Invoke-Case 'Ubuntu full suite without trusted-base candidates fails' 1 -workflow $fullWithoutTrustedBase -expectText 'cost-full-suite-commands'
    Invoke-Case 'Windows smoke selected without an OS guard fails' 1 -workflow $workflowSource.Replace("`$useWindowsSmoke = `$env:RUNNER_OS -eq 'Windows' -and `$env:WINDOWS_COVERAGE -ne 'full'", "`$useWindowsSmoke = `$env:WINDOWS_COVERAGE -ne 'full'") -expectText 'cost-windows-coverage-selection'
    Invoke-Case 'full Windows certification option removal fails' 1 -workflow $workflowSource.Replace("          - full`n", "          - complete`n") -expectText 'cost-windows-full-certification-dispatch'
    Invoke-Case 'missing change scope classification fails' 1 -workflow ([Regex]::new('(?m)^        id: scope\n').Replace($workflowSource, '', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'head candidate work without the scope guard fails' 1 -workflow ([Regex]::new("(?m)^        if: steps\.scope\.outputs\.scope != 'records-and-plans'\n").Replace($workflowSource, '', 1)) -expectText 'change-scope-guard:v3-architecture'
    Invoke-Case 'classification outside the trusted base fails' 1 -workflow ([Regex]::new('"\$env:GUARD_BASE/docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1" -HeadRoot \$env:GITHUB_WORKSPACE -BaseSha \$env:GUARD_BASE_SHA -Mode Scope').Replace($workflowSource, './docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1 -HeadRoot $env:GITHUB_WORKSPACE -BaseSha $env:GUARD_BASE_SHA -Mode Scope', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'a classification step in another mode fails' 1 -workflow ([Regex]::new('-Mode Scope').Replace($workflowSource, '-Mode Validate', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'a classification step that blocks the run fails' 1 -workflow ([Regex]::new('(?m)^        continue-on-error: true\n').Replace($workflowSource, '', 1)) -expectText 'change-scope-fails-open:v3-architecture'
    Invoke-Case 'an undeclared classification implementation fails' 1 -jobs $jobsSource.Replace('"implementation": "docs/guards/V3_ifx/trusted-base/Get-IFXChangeScope.ps1"', '"implementation": "docs/guards/V3_ifx/trusted-base/Get-IFXMissingScope.ps1"') -expectText 'change-scope-entry-point'
    Invoke-Case 'an undeclared inheriting check fails' 1 -jobs $jobsSource.Replace('"inheritingChecks": ["v3-architecture"', '"inheritingChecks": ["v3-legacy-guard", "v3-architecture"') -expectText 'change-scope-inheriting-checks'
    $costStart = $jobsSource.IndexOf('  "costControls": {', [StringComparison]::Ordinal)
    $costEnd = $jobsSource.IndexOf('  "changeScope": {', [StringComparison]::Ordinal)
    if ($costStart -lt 0 -or $costEnd -le $costStart) { throw 'Fixture could not locate the cost control declaration.' }
    $noCostJobs = $jobsSource.Remove($costStart, $costEnd - $costStart)
    Invoke-Case 'undeclared cost controls skip their checks' 0 -jobs $noCostJobs -workflow ([Regex]::Replace($workflowSource, '(?m)^concurrency:\n(  .*\n)+', ''))
    $inactiveJobs = [Regex]::Replace($jobsSource, '\s*"trustedBase":\s*\{[^}]*\},', '')
    if ($inactiveJobs -eq $jobsSource) { throw 'Fixture could not remove the trusted base declaration.' }
    Invoke-Case 'undeclared trusted base execution skips runner checks' 0 -jobs $inactiveJobs -workflow $workflowSource.Replace('-GateId v3-historical-integrity', '-GateId v3-other')
    Write-Host 'IFX CI contract tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
