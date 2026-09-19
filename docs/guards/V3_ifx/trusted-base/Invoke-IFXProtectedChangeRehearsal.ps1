[CmdletBinding()]
param(
    # The trusted base to rehearse against; its own trusted runner, verifier and generator are used.
    [string] $BaseRevision = 'HEAD',
    [string] $Repository = '.',
    [string] $EvidencePath,
    # Compares only HistoricalIntegrity in the candidate parity step instead of the full fixed corpus.
    [switch] $QuickParity,
    [switch] $KeepWorkDirectory
)

# Plan 06 P4.7 two-PR rehearsal (CP06c). In a disposable clone outside the repository, one prepared change combines a
# protected directory move, an editable policy weakening and a trusted component change. Everything is judged by the
# trusted runner, verifier and generator of the base commit itself:
#  1. the three authorizations are generated from the prepared change and merged to base alone (authorization PR);
#  2. the same change opened before the authorizations exist fails;
#  3. the change PR on the authorized base deletes all three records and passes the trusted Diff, candidate verification
#     with parity, and Validate for its explicit head;
#  4. after it merges, a second pull request that tries to consume the same authorizations fails.
# The evidence report lists every commit and verdict. Nothing is pushed.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$repositoryRoot = Get-GuardFullPath $Repository
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$work = Get-GuardFullPath (Join-Path $tempRoot "ifx-rehearsal-$([Guid]::NewGuid().ToString('N').Substring(0, 8))")
if (Test-GuardPathWithin $work $repositoryRoot) { throw 'The rehearsal must run outside the repository.' }
$clone = Join-Path $work 'h'
$utf8 = [Text.UTF8Encoding]::new($false)
$identity = @('-c', 'user.name=guard-rehearsal', '-c', 'user.email=guard-rehearsal@example.invalid', '-c', 'commit.gpgsign=false')
$authorizations = 'docs/guards/V3_ifx/stages/diff/authorizations'
$decisions = 'docs/guards/V3_ifx/decisions/history'
$steps = [Collections.Generic.List[object]]::new()

function Invoke-RehearsalGit([string[]] $Arguments) {
    $output = @(& git -C $clone @identity @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join ' | ')" }
    return , $output
}
function Get-Commit([string] $Revision) { return (Invoke-RehearsalGit @('rev-parse', $Revision))[0] }
function New-BaseTree([string] $Name, [string] $Commit) {
    $path = Join-Path $work $Name
    [void](Invoke-RehearsalGit @('worktree', 'add', '-q', '--detach', $path, $Commit))
    return $path
}
function New-Commit([string] $Name, [string] $From, [scriptblock] $Edits, [string] $PlanId) {
    [void](Invoke-RehearsalGit @('checkout', '-q', '-f', '-B', "rehearsal/$Name", $From))
    & $Edits
    [void](Invoke-RehearsalGit @('add', '-A'))
    if ($PlanId) {
        [string[]] $planned = Invoke-RehearsalGit @('diff', '--cached', '--no-renames', '--name-only', $From)
        $planPath = "docs/guards/plans/$PlanId.plan.json"
        $plan = [ordered]@{
            formatVersion = 1; id = $PlanId; title = "Rehearsal $Name"; goal = 'Rehearse the Plan 06 two-PR protocol.'
            acceptanceCriteria = @('The trusted verdict matches the rehearsal expectation.')
            plannedPaths = @(@($planned) + @($planPath, "docs/guards/plans/$PlanId.md") | Sort-Object -Unique)
            areaIds = @('GuardDocs', 'GuardPackage'); ruleIds = @(); validationCommands = @('ifx-package-test')
            decisionPaths = @(
                "$decisions/20260916-v3-stage-d02-v3-backup-retirement.json",
                "$decisions/20260916-v3-stage-d10-protected-change-authorization.json",
                "$decisions/20260917-v3-stage-d20-authorization-consumption-and-break-glass.json",
                "$decisions/20260917-v3-stage-d23-protected-change-obligations.json",
                "$decisions/20260917-v3-stage-d24-policy-config-dual-track.json")
        }
        [IO.File]::WriteAllText((Join-Path $clone $planPath), ($plan | ConvertTo-Json -Depth 5) + "`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $clone "docs/guards/plans/$PlanId.md"), "# Rehearsal $Name`n", $utf8)
        [void](Invoke-RehearsalGit @('add', '-A'))
    }
    [void](Invoke-RehearsalGit @('commit', '-q', '--allow-empty', '-m', "rehearsal: $Name"))
    return Get-Commit 'HEAD'
}
function Invoke-Trusted([string] $Tree, [string] $Script, [string[]] $Arguments) {
    return Invoke-GuardIsolatedPwsh (Join-Path $Tree "docs/guards/V3_ifx/trusted-base/$Script") $Arguments -WorkingDirectory $clone
}
function Add-Step([string] $Id, [string] $Description, [string] $BaseSha, [string] $HeadSha, [int] $Expected, [object] $Run, [string] $ExpectText, [string] $SummaryFile, [string] $CheckId) {
    $text = $Run.Output -replace '\s+', ' '
    $ok = $Run.ExitCode -eq $Expected -and (-not $ExpectText -or $text.Contains($ExpectText, [StringComparison]::Ordinal))
    $check = $null
    if ($SummaryFile -and [IO.File]::Exists($SummaryFile)) { $check = @((Get-Content -LiteralPath $SummaryFile -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq $CheckId }) | Select-Object -First 1 }
    $evidence = @($Run.Output -split "`n" | Where-Object { $_ -match '^FAIL |Protected change verification|Trusted base run|Trusted component candidate check|Policy candidate validation' } | ForEach-Object { $_.Trim() } | Select-Object -Unique -First 12)
    if (-not $ok) { $evidence += @($Run.Output -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 20 | ForEach-Object { $_.Trim() }) }
    # Evidence is committed, so machine-specific temporary paths are replaced.
    $evidence = @($evidence | ForEach-Object { $_.Replace($tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar), '<temp>') })
    $steps.Add([ordered]@{ id = $Id; description = $Description; baseSha = $BaseSha; headSha = $HeadSha; expectedExit = $Expected; exit = $Run.ExitCode; asExpected = $ok; check = if ($check) { [ordered]@{ id = $check.id; status = $check.status; reason = $check.reason } } else { $null }; evidence = $evidence })
    Write-Host ("[{0}] {1}: exit {2} (expected {3})" -f $(if ($ok) { 'OK' } else { 'UNEXPECTED' }), $Id, $Run.ExitCode, $Expected)
}

$moveEdit = { [void](Invoke-RehearsalGit @('mv', 'docs/guards/V3/architecture', 'docs/guards/V3/design')) }
$ruleFile = 'docs/guards/V3_ifx/stages/post/rules/L1.2.json'
$ruleEdit = {
    $path = Join-Path $clone $ruleFile
    [IO.File]::WriteAllText($path, [IO.File]::ReadAllText($path).Replace('"No legacy Abstractions project"', '"No legacy Abstractions projects"'), $utf8)
    # A complete policy change also regenerates the profile views with the base renderer.
    $render = Invoke-GuardIsolatedPwsh (Join-Path $baseTree 'docs/guards/V3/commands/Invoke-V3Docs.ps1') @('-Mode', 'Render', '-ProfileLayoutPath', (Join-Path $clone 'docs/guards/V3_ifx/shared/profile-layout.json'), '-TargetRoot', $clone, '-PackageDirectory', (Join-Path $clone 'docs/guards/V3_ifx')) -WorkingDirectory $clone
    if ($render.ExitCode -ne 0) { throw "Profile view rendering failed: $($render.Output)" }
}
$engineFile = 'docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1'
$engineEdit = { $path = Join-Path $clone $engineFile; [IO.File]::WriteAllText($path, [IO.File]::ReadAllText($path).Replace("`$ErrorActionPreference = 'Stop'", "# rehearsal: behaviour-equivalent change`n`$ErrorActionPreference = 'Stop'"), $utf8) }
$change = { & $moveEdit; & $ruleEdit; & $engineEdit }
$records = @('rehearsal-move', 'rehearsal-weaken-policy', 'rehearsal-trusted-base')

$failed = $true
try {
    [void][IO.Directory]::CreateDirectory($work)
    $baseSha = Resolve-GuardCommit $repositoryRoot $BaseRevision
    [void](& git -C $work clone -q --shared --no-checkout $repositoryRoot $clone 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot clone the repository for the rehearsal.' }
    [void](Invoke-RehearsalGit @('checkout', '-q', '--detach', $baseSha))
    $baseTree = New-BaseTree 'b' $baseSha
    Write-Host "Rehearsal base $baseSha"

    # ---- authorization PR
    $prepared = New-Commit 'prepared' $baseSha $change $null
    $changePlan = 'docs/guards/plans/20260917-rehearsal-change.plan.json'
    $generator = @('-BaseRevision', $baseSha, '-HeadRevision', $prepared, '-PlanPath', $changePlan, '-DecisionPaths', "$decisions/20260917-v3-stage-d23-protected-change-obligations.json,$decisions/20260917-v3-stage-d24-policy-config-dual-track.json", '-Repository', $clone)
    foreach ($spec in @(
            @('rehearsal-move', @('-Operation', 'move', '-SourcePath', 'docs/guards/V3/architecture', '-DestinationPath', 'docs/guards/V3/design')),
            @('rehearsal-weaken-policy', @('-Operation', 'weaken-policy')),
            @('rehearsal-trusted-base', @('-ParityContract', 'Rehearsal: verdicts unchanged on the fixed corpus.')))) {
        $run = Invoke-Trusted $baseTree 'New-IFXTrustedBaseAuthorization.ps1' (@('-Id', $spec[0], '-OutputPath', (Join-Path $work "$($spec[0]).json")) + $spec[1] + $generator)
        if ($run.ExitCode -ne 0) { throw "Authorization generator failed for $($spec[0]): $($run.Output)" }
    }
    $authorization = New-Commit 'authorization' $baseSha { foreach ($id in $records) { [IO.File]::Copy((Join-Path $work "$id.json"), (Join-Path $clone "$authorizations/$id.json"), $true) } } '20260917-rehearsal-authorization'
    Add-Step 'authorization-pr-diff' 'Authorization PR passes the trusted Diff.' $baseSha $authorization 0 (Invoke-Trusted $baseTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $baseSha, '-Mode', 'Diff', '-PlanPath', 'docs/guards/plans/20260917-rehearsal-authorization.plan.json', '-BaseRef', $baseSha, '-HeadRef', $authorization, '-GateId', 'v3-pre-diff')) 'Trusted base run passed' (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') 'protected-changes'
    Add-Step 'authorization-pr-candidates' 'Authorization PR changes no trusted component.' $baseSha $authorization 0 (Invoke-Trusted $baseTree 'Test-IFXTrustedBaseCandidate.ps1' @('-TargetRoot', $clone, '-BaseSha', $baseSha, '-HeadRevision', $authorization)) 'no trusted component changes' $null $null

    # ---- the change opened before its authorizations exist
    $early = New-Commit 'early-change' $baseSha $change '20260917-rehearsal-change'
    Add-Step 'early-change-diff' 'The change fails before the authorization PR merges.' $baseSha $early 1 (Invoke-Trusted $baseTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $baseSha, '-Mode', 'Diff', '-PlanPath', $changePlan, '-BaseRef', $baseSha, '-HeadRef', $early, '-GateId', 'v3-pre-diff')) 'Uncovered' (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') 'protected-changes'

    # ---- change PR on the authorized base
    [void](Invoke-RehearsalGit @('checkout', '-q', '-f', '-B', 'rehearsal/base', $baseSha))
    [void](Invoke-RehearsalGit @('merge', '-q', '--no-ff', '-m', 'rehearsal: merge authorization PR', $authorization))
    $authorizedBase = Get-Commit 'HEAD'
    $authorizedTree = New-BaseTree 'm' $authorizedBase
    $consuming = New-Commit 'change' $authorizedBase { & $change; foreach ($id in $records) { [IO.File]::Delete((Join-Path $clone "$authorizations/$id.json")) } } '20260917-rehearsal-change'
    Add-Step 'change-pr-diff' 'The change PR consumes all three authorizations in the trusted Diff.' $authorizedBase $consuming 0 (Invoke-Trusted $authorizedTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $authorizedBase, '-Mode', 'Diff', '-PlanPath', $changePlan, '-BaseRef', $authorizedBase, '-HeadRef', $consuming, '-GateId', 'v3-pre-diff')) 'Trusted base run passed' (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') 'protected-changes'
    Add-Step 'change-pr-candidates' 'The trusted component change passes base-owned validation and parity.' $authorizedBase $consuming 0 (Invoke-Trusted $authorizedTree 'Test-IFXTrustedBaseCandidate.ps1' (@('-TargetRoot', $clone, '-BaseSha', $authorizedBase, '-HeadRevision', $consuming) + $(if ($QuickParity) { @('-ParityModes', 'HistoricalIntegrity') } else { @() }))) 'authorized change of tcb.engine.historical-integrity' $null $null
    Add-Step 'change-pr-policy-candidates' 'The head policy candidates of the change PR pass base validation.' $authorizedBase $consuming 0 (Invoke-Trusted $authorizedTree 'Test-IFXPolicyCandidates.ps1' @('-TargetRoot', $clone, '-BaseSha', $authorizedBase, '-HeadRevision', $consuming, '-ReportPath', (Join-Path $work 'policy-candidates.json'))) 'Policy candidate validation passed' $null $null
    [void](Invoke-RehearsalGit @('checkout', '-q', '-f', $consuming))
    Add-Step 'change-pr-validate' 'Validate passes for the explicit change head.' $authorizedBase $consuming 0 (Invoke-Trusted $authorizedTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $authorizedBase, '-Mode', 'Validate', '-HeadRef', $consuming, '-GateId', 'v3-architecture')) 'Trusted base run passed' (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-validate.json') 'domain-authority-candidates'

    # ---- replay after the change PR merges
    [void](Invoke-RehearsalGit @('checkout', '-q', '-f', 'rehearsal/base'))
    [void](Invoke-RehearsalGit @('merge', '-q', '--no-ff', '-m', 'rehearsal: merge change PR', $consuming))
    $mergedBase = Get-Commit 'HEAD'
    $mergedTree = New-BaseTree 'n' $mergedBase
    $replay = New-Commit 'replay' $authorizedBase { & $ruleEdit; [IO.File]::Delete((Join-Path $clone "$authorizations/rehearsal-weaken-policy.json")) } '20260917-rehearsal-replay'
    Add-Step 'replay-diff' 'A second PR cannot consume an authorization that the merged change already consumed.' $mergedBase $replay 1 (Invoke-Trusted $mergedTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $mergedBase, '-Mode', 'Diff', '-PlanPath', 'docs/guards/plans/20260917-rehearsal-replay.plan.json', '-BaseRef', $mergedBase, '-HeadRef', $replay, '-GateId', 'v3-pre-diff')) 'the record is not in the base commit' (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') 'protected-changes'

    $failed = @($steps | Where-Object { -not $_.asExpected }).Count -gt 0
    $report = [ordered]@{
        formatVersion = 1; check = 'protected-change-rehearsal'; status = if ($failed) { 'fail' } else { 'pass' }
        baseSha = $baseSha; parity = if ($QuickParity) { 'HistoricalIntegrity' } else { 'full fixed corpus' }
        commits = [ordered]@{ prepared = $prepared; authorization = $authorization; early = $early; authorizedBase = $authorizedBase; change = $consuming; mergedBase = $mergedBase; replay = $replay }
        authorizations = @($records | ForEach-Object { [ordered]@{ path = "$authorizations/$_.json"; record = (Get-Content -LiteralPath (Join-Path $work "$_.json") -Raw | ConvertFrom-Json) } })
        steps = @($steps)
    }
    $destination = if ($EvidencePath) { [IO.Path]::GetFullPath($EvidencePath) } else { Join-Path $repositoryRoot 'artifacts/guards/v3-ifx/trusted-base/protected-change-rehearsal.json' }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::WriteAllText($destination, ($report | ConvertTo-Json -Depth 20) + "`n", $utf8)
    Write-Host "Rehearsal $($report.status): $destination"
}
finally {
    if (-not $KeepWorkDirectory -and [IO.Directory]::Exists($work)) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failed) { exit 1 }
