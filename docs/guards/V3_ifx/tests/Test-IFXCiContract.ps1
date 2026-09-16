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
    Write-Host 'IFX CI contract tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
