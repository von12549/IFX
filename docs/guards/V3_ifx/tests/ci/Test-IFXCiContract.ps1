[CmdletBinding()]
param()

# Positive and negative fixtures for ci/Invoke-IFXCiContract.ps1 (Plan 06 P1.3).

# Stage-oriented test group: CI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { $package = [IO.Path]::GetFullPath((Join-Path $package '..')) }
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { throw 'Cannot resolve the IFX guard package root.' }
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-ci-contract-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$verifier = Join-Path $package 'ci/Invoke-IFXCiContract.ps1'
$publicFacade = Join-Path $package 'commands/Invoke-IFXGuardrails.ps1'
$utf8 = [Text.UTF8Encoding]::new($false)
$workflowSource = [IO.File]::ReadAllText((Join-Path $repository '.github/workflows/v3-ifx-guardrails.yml')).Replace("`r`n", "`n")
$facadeSource = [IO.File]::ReadAllText($publicFacade).Replace("`r`n", "`n")
$requiredChecksPath = Join-Path $package 'stages/ci/required-checks.json'
$usingRequiredChecks = [IO.File]::Exists($requiredChecksPath)
$declarationPath = if ($usingRequiredChecks) { $requiredChecksPath } else { Join-Path $package 'ci/jobs.json' }
$requiredChecksSource = [IO.File]::ReadAllText($declarationPath).Replace("`r`n", "`n")

function New-Ruleset([string[]] $contexts, [bool] $strict = $true, [string] $enforcement = 'active') {
    $declaration = $requiredChecksSource | ConvertFrom-Json
    return [ordered]@{
        id = $declaration.ruleset.id; name = $declaration.ruleset.name; enforcement = $enforcement
        rules = @(
            [ordered]@{ type = 'deletion' },
            [ordered]@{ type = 'required_status_checks'; parameters = [ordered]@{ strict_required_status_checks_policy = $strict; required_status_checks = @($contexts | ForEach-Object { [ordered]@{ context = $_; integration_id = 15368 } }) } }
        )
    } | ConvertTo-Json -Depth 10
}
$allChecks = @(($requiredChecksSource | ConvertFrom-Json).jobs | ForEach-Object { $_.id })

function Invoke-Case([string] $label, [int] $expected, [string] $workflow = $workflowSource, [string] $facade = $facadeSource, [string] $requiredChecks = $requiredChecksSource, [string] $ruleset, [string] $expectText) {
    $case = Join-Path $fixture ([Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory((Join-Path $case '.github/workflows'))
    [IO.File]::WriteAllText((Join-Path $case '.github/workflows/v3-ifx-guardrails.yml'), $workflow, $utf8)
    if ($usingRequiredChecks) {
        [void][IO.Directory]::CreateDirectory((Join-Path $case 'docs/guards/V3_ifx/stages/ci'))
        [void][IO.Directory]::CreateDirectory((Join-Path $case 'docs/guards/V3_ifx/commands'))
        [IO.File]::WriteAllText((Join-Path $case 'docs/guards/V3_ifx/stages/ci/required-checks.json'), $requiredChecks, $utf8)
        [IO.File]::WriteAllText((Join-Path $case 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1'), $facade, $utf8)
        $arguments = @('-NoProfile', '-File', $verifier, '-TargetRoot', $case, '-RequiredChecksPath', 'docs/guards/V3_ifx/stages/ci/required-checks.json')
    } else {
        [void][IO.Directory]::CreateDirectory((Join-Path $case 'docs/guards/V3_ifx/ci'))
        [IO.File]::WriteAllText((Join-Path $case 'docs/guards/V3_ifx/ci/jobs.json'), $requiredChecks, $utf8)
        $arguments = @('-NoProfile', '-File', $verifier, '-TargetRoot', $case, '-JobsPath', 'docs/guards/V3_ifx/ci/jobs.json')
    }
    if ($ruleset) {
        [IO.File]::WriteAllText((Join-Path $case 'ruleset.json'), $ruleset, $utf8)
        $arguments += @('-RulesetJsonPath', 'ruleset.json')
    }
    $output = @(& pwsh @arguments 2>&1) -join ' | '
    if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
    if ($expectText -and -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not report '$expectText': $output" }
    Write-Host "PASS $label"
}
function Assert-FacadeFailure([string] $label, [string[]] $arguments, [string] $expectText) {
    $output = @(& pwsh -NoProfile -File $publicFacade @arguments 2>&1) -join ' | '
    if ($LASTEXITCODE -eq 0 -or -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not fail with '$expectText': $output" }
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
    Invoke-Case $(if ($usingRequiredChecks) { 'current workflow matches required-checks.json' } else { 'current workflow matches jobs.json' }) 0
    Invoke-Case 'matching ruleset passes' 0 -ruleset (New-Ruleset $allChecks)
    Invoke-Case 'renamed workflow check fails' 1 -workflow $workflowSource.Replace('    name: v3-quality-frontend', '    name: v3-quality-web') -expectText 'declaration-matches-workflow'
    Invoke-Case 'undeclared workflow job fails' 1 -requiredChecks ($requiredChecksSource -replace '(?m)^\s*\{ "id": "v3-specialized-g05".*\r?\n', '') -expectText 'declaration-matches-workflow'
    Invoke-Case 'wrong required count fails' 1 -requiredChecks $requiredChecksSource.Replace('"requiredCheckCount": 13', '"requiredCheckCount": 12') -expectText 'declaration-required-count'
    Invoke-Case 'trigger declaration mismatch fails' 1 -requiredChecks $requiredChecksSource.Replace('"id": "v3-historical-integrity", "mode": "historical-integrity", "trigger": "pull-request-and-main"', '"id": "v3-historical-integrity", "mode": "historical-integrity", "trigger": "pull-request"') -expectText 'declaration-trigger:v3-historical-integrity'
    Invoke-Case 'unknown trigger fails' 1 -requiredChecks $requiredChecksSource.Replace('"id": "v3-architecture", "mode": "architecture", "trigger": "pull-request-and-main"', '"id": "v3-architecture", "mode": "architecture", "trigger": "history-change-schedule-manual"') -expectText $(if ($usingRequiredChecks) { 'JSON is not valid with the schema' } else { 'unknown trigger' })
    Invoke-Case 'non-blocking job fails' 1 -requiredChecks $requiredChecksSource.Replace('"id": "v3-quality-assembly", "mode": "quality", "gate": "assembly", "trigger": "pull-request-and-main", "blocking": true', '"id": "v3-quality-assembly", "mode": "quality", "gate": "assembly", "trigger": "pull-request-and-main", "blocking": false') -expectText $(if ($usingRequiredChecks) { 'JSON is not valid with the schema' } else { 'declaration-blocking:v3-quality-assembly' })
    Invoke-Case 'matrix expansion change fails' 1 -workflow $workflowSource.Replace('os: [ubuntu-latest, windows-latest]', 'os: [ubuntu-latest]') -expectText 'declaration-matches-workflow'
    Invoke-Case 'pull-request job without condition fails' 1 -workflow $workflowSource.Replace("    if: github.event_name == 'pull_request'`n", '') -expectText 'declaration-trigger:v3-pre-diff'
    Invoke-Case 'missing push trigger fails' 1 -workflow $workflowSource.Replace("  push:`n    branches: [main]`n", '') -expectText 'workflow-triggers'
    if ($usingRequiredChecks) { Invoke-Case 'tab-indented YAML fails structural parse' 1 -workflow $workflowSource.Replace('  pull_request:', "`tpull_request:") -expectText 'workflow-yaml-canonical' }
    Invoke-Case 'ruleset missing a required context fails' 1 -ruleset (New-Ruleset @($allChecks | Where-Object { $_ -ne 'v3-quality-frontend' })) -expectText 'ruleset-contexts'
    Invoke-Case 'ruleset extra context fails' 1 -ruleset (New-Ruleset @($allChecks + 'legacy-guard')) -expectText 'ruleset-contexts'
    Invoke-Case 'ruleset without strict fails' 1 -ruleset (New-Ruleset $allChecks $false) -expectText 'ruleset-strict'
    Invoke-Case 'inactive ruleset fails' 1 -ruleset (New-Ruleset $allChecks $true 'evaluate') -expectText 'ruleset-active'
    Invoke-Case 'check without its trusted base gate fails' 1 -workflow $workflowSource.Replace('-GateId v3-historical-integrity', '-GateId v3-other') -expectText 'trusted-base-runner:v3-historical-integrity'
    Invoke-Case 'matrix check without its trusted base gate fails' 1 -workflow $workflowSource.Replace('-GateId v3-cross-platform-${{ matrix.os }}', '-GateId v3-cross-platform-ubuntu-latest') -expectText 'trusted-base-runner:v3-cross-platform-windows-latest'
    if ($usingRequiredChecks) {
        Invoke-Case 'first verdict executable outside base fails' 1 -workflow $workflowSource.Replace('pwsh -NoProfile -File "$env:GUARD_BASE/docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1" -TrustedBase -TargetRoot $env:GITHUB_WORKSPACE -BaseSha $env:GUARD_BASE_SHA -Mode HistoricalIntegrity', 'pwsh -NoProfile -File "./docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1" -TargetRoot $env:GITHUB_WORKSPACE -BaseSha $env:GUARD_BASE_SHA -Mode HistoricalIntegrity') -expectText 'trusted-base-first-verdict:v3-historical-integrity'
        Invoke-Case 'workflow internal script entry fails' 1 -workflow $workflowSource.Replace('"./docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1" -Mode CandidateTests -CandidateSuite Architecture', '"./docs/guards/V3_ifx/tests/pre/Test-IFXPre.ps1"') -expectText 'workflow-public-commands'
    }
    Invoke-Case 'head dispatcher run in place fails' 1 -workflow $workflowSource.Replace('-Mode HistoricalIntegrity -GateId v3-historical-integrity', "-Mode HistoricalIntegrity -GateId v3-historical-integrity`n          ./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode HistoricalIntegrity") -expectText 'trusted-base-no-head-dispatcher:v3-historical-integrity'
    Invoke-Case 'job without the base worktree fails' 1 -workflow ([Regex]::new('git worktree add --detach').Replace($workflowSource, 'git worktree list', 1)) -expectText 'trusted-base-worktree:v3-pre-diff'
    # Plan 06 D28: cost controls and the base-owned change scope are declared in required-checks.json and enforced in the workflow.
    Invoke-Case 'missing concurrency fails' 1 -workflow ([Regex]::Replace($workflowSource, '(?m)^concurrency:\n(  .*\n)+', '')) -expectText 'cost-concurrency'
    Invoke-Case 'keeping superseded runs fails' 1 -workflow $workflowSource.Replace('  cancel-in-progress: true', '  cancel-in-progress: false') -expectText 'cost-concurrency'
    Invoke-Case 'undeclared schedule fails' 1 -workflow $workflowSource.Replace("    - cron: '17 3 1 * *'", "    - cron: '17 3 * * 1'") -expectText 'cost-schedule'
    Invoke-Case 'missing package cache fails' 1 -workflow ([Regex]::Replace($workflowSource, '(?m)^      - name: Cache reviewed guard packages\n(        .*\n|          .*\n)+', '', 1)) -expectText 'cost-package-cache:v3-architecture'
    Invoke-Case 'package cache not keyed by the reviewed locks fails' 1 -workflow $workflowSource.Replace("hashFiles('docs/guards/*/build/locks/*.packages.lock.json')", "github.sha") -expectText 'cost-package-cache:v3-architecture'
    $smokeWithoutBuild = Edit-MarkedBlock $facadeSource '# BEGIN WINDOWS PORTABILITY SMOKE' '# END WINDOWS PORTABILITY SMOKE' "        ,@('docs/guards/V3/tests/Test-V3BuildBaseline.ps1')`n" ''
    Invoke-Case 'Windows smoke without the locked build baseline fails' 1 -facade $smokeWithoutBuild -expectText 'cost-windows-smoke-commands'
    $fullWithoutTrustedBase = Edit-MarkedBlock $facadeSource '# BEGIN FULL CROSS-PLATFORM CANDIDATE SUITE' '# END FULL CROSS-PLATFORM CANDIDATE SUITE' "        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTrustedBase.ps1')" "        ,@('docs/guards/V3_ifx/tests/pre/Test-IFXPre.ps1')"
    Invoke-Case 'Ubuntu full suite without trusted-base candidates fails' 1 -facade $fullWithoutTrustedBase -expectText 'cost-full-suite-commands'
    Invoke-Case 'Windows smoke selected without an OS guard fails' 1 -workflow $workflowSource.Replace("`$coverage = if (`$env:RUNNER_OS -eq 'Windows') { `$env:WINDOWS_COVERAGE } else { 'full' }", "`$coverage = `$env:WINDOWS_COVERAGE") -expectText 'cost-windows-coverage-selection'
    Invoke-Case 'full Windows certification option removal fails' 1 -workflow $workflowSource.Replace("          - full`n", "          - complete`n") -expectText 'cost-windows-full-certification-dispatch'
    Invoke-Case 'missing change scope classification fails' 1 -workflow ([Regex]::new('(?m)^        id: scope\n').Replace($workflowSource, '', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'head candidate work without the scope guard fails' 1 -workflow ([Regex]::new("(?m)^        if: steps\.scope\.outputs\.scope != 'records-and-plans'\n").Replace($workflowSource, '', 1)) -expectText 'change-scope-guard:v3-architecture'
    $scopePattern = if ($usingRequiredChecks) { '"\$env:GUARD_BASE/docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1" -TrustedBase -TargetRoot \$env:GITHUB_WORKSPACE -BaseSha \$env:GUARD_BASE_SHA -Mode Scope' } else { '"\$env:GUARD_BASE/docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1" -HeadRoot \$env:GITHUB_WORKSPACE -BaseSha \$env:GUARD_BASE_SHA -Mode Scope' }
    Invoke-Case 'classification outside the trusted base fails' 1 -workflow ([Regex]::new($scopePattern).Replace($workflowSource, './docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1 -HeadRoot $env:GITHUB_WORKSPACE -BaseSha $env:GUARD_BASE_SHA -Mode Scope', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'a classification step in another mode fails' 1 -workflow ([Regex]::new('-Mode Scope').Replace($workflowSource, '-Mode Validate', 1)) -expectText 'change-scope-step:v3-architecture'
    Invoke-Case 'a classification step that blocks the run fails' 1 -workflow ([Regex]::new('(?m)^        continue-on-error: true\n').Replace($workflowSource, '', 1)) -expectText 'change-scope-fails-open:v3-architecture'
    Invoke-Case 'an undeclared classification implementation fails' 1 -requiredChecks $requiredChecksSource.Replace('"implementation": "docs/guards/V3_ifx/trusted-base/Get-IFXChangeScope.ps1"', '"implementation": "docs/guards/V3_ifx/trusted-base/Get-IFXMissingScope.ps1"') -expectText 'change-scope-entry-point'
    Invoke-Case 'an undeclared inheriting check fails' 1 -requiredChecks $requiredChecksSource.Replace('"inheritingChecks": ["v3-architecture"', '"inheritingChecks": ["v3-legacy-guard", "v3-architecture"') -expectText 'change-scope-inheriting-checks'
    $costStart = $requiredChecksSource.IndexOf('  "costControls": {', [StringComparison]::Ordinal)
    $costEnd = $requiredChecksSource.IndexOf('  "changeScope": {', [StringComparison]::Ordinal)
    if ($costStart -lt 0 -or $costEnd -le $costStart) { throw 'Fixture could not locate the cost control declaration.' }
    $noCostChecks = $requiredChecksSource.Remove($costStart, $costEnd - $costStart)
    Invoke-Case 'cost control declaration behavior' $(if ($usingRequiredChecks) { 1 } else { 0 }) -requiredChecks $noCostChecks -workflow ([Regex]::Replace($workflowSource, '(?m)^concurrency:\n(  .*\n)+', '')) -expectText $(if ($usingRequiredChecks) { 'JSON is not valid with the schema' } else { $null })
    $inactiveChecks = [Regex]::Replace($requiredChecksSource, '\s*"trustedBase":\s*\{[^}]*\},', '')
    if ($inactiveChecks -eq $requiredChecksSource) { throw 'Fixture could not remove the trusted base declaration.' }
    Invoke-Case 'trusted base activation declaration behavior' $(if ($usingRequiredChecks) { 1 } else { 0 }) -requiredChecks $inactiveChecks -workflow $workflowSource.Replace('-GateId v3-historical-integrity', '-GateId v3-other') -expectText $(if ($usingRequiredChecks) { 'JSON is not valid with the schema' } else { $null })
    if ($usingRequiredChecks) {
        Assert-FacadeFailure 'candidate suite is explicit' @('-Mode','CandidateTests','-TargetRoot',$repository) 'CandidateTests requires -CandidateSuite.'
        Assert-FacadeFailure 'smoke coverage is CrossPlatform-only' @('-Mode','CandidateTests','-CandidateSuite','Architecture','-CandidateCoverage','smoke','-TargetRoot',$repository) 'CandidateCoverage is only available for the CrossPlatform candidate suite.'
        Assert-FacadeFailure 'TCB candidate SHA is explicit' @('-Mode','TrustedComponentCandidate','-TargetRoot',$repository) 'TrustedComponentCandidate requires -BaseSha.'
        Assert-FacadeFailure 'trusted-base SHA is explicit' @('-Mode','Validate','-TrustedBase','-TargetRoot',$repository) '-TrustedBase requires -BaseSha.'
    }
    Write-Host 'IFX CI contract tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
