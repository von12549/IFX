# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) step C3: local rehearsal of the pull request sequence P1, P2a, P2,
# P3a, P3 on codex/guards-principles-plan. It follows V3's own two-PR rehearsal (Invoke-IFXProtectedChangeRehearsal.ps1):
# in a disposable clone outside the repository, every verdict comes from the trusted runner, verifier and generator of
# the simulated base commit itself, and merges are simulated as merge commits (RC5).
#  - P1: trusted Diff, Validate, head candidate package tests, Architecture, Historical Integrity and solution quality.
#  - P2 and P3: the change opened before its records exist fails; the records are generated from the prepared change;
#    the authorization PR alone passes; the change consuming them passes the trusted Diff, candidate verification with
#    parity, policy candidate validation, Validate, candidate package tests, Architecture, Historical Integrity and G03.
#  - P3 negative controls: an additional, a differently cased and a missing entry fail the new allowlist; the unchanged
#    base test rejects v4-adoption; a second PR cannot consume a consumed record.
#  - Final state: docs/guards is exactly plans, V3, V3_ifx, v4-adoption; copied blobs equal the development branch.
# Contexts not run here (quality assembly and frontend, specialized G04/G05/Plan04/Database, the Linux and Windows
# cross-platform candidate suites) run in CI on every pull request. Nothing is pushed.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $WorkRoot = 'D:/IFX-Root/guard-runtime/i2c',
    [string] $OutputDirectory = 'artifacts/guards/p10-ifx-i2c/c3-rehearsal',
    [switch] $SkipQuality,
    [switch] $QuickParity,
    [switch] $KeepWorkDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$repositoryPath = [IO.Path]::GetFullPath($RepositoryRoot)
Import-Module (Join-Path $repositoryPath 'docs/guards/V3_ifx/trusted-base/TrustedBase.psm1') -Force
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pr-spec.json') | ConvertFrom-Json -Depth 20
$output = [IO.Path]::GetFullPath((Join-Path $repositoryPath $OutputDirectory))
Assert-IFXI2C (-not [IO.Directory]::Exists($output)) "The rehearsal output already exists: $output"
$work = [IO.Path]::GetFullPath((Join-Path $WorkRoot "c3-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"))
Assert-IFXI2C (-not (Test-GuardPathWithin $work $repositoryPath)) 'The rehearsal must run outside the repository.'
$clone = Join-Path $work 'h'
$logs = Join-Path $output 'logs'
$recordsOut = Join-Path $output 'records'
$tempRoot = [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar)
$authorizationDirectory = [string]$spec.authorizationDirectory
$steps = [Collections.Generic.List[object]]::new()
$commits = [ordered]@{}
$builds = [ordered]@{}
$stepNumber = 0

function CloneGit([string[]] $Arguments) { return Invoke-IFXI2CGit $clone $Arguments }
function Get-Commit([string] $Revision) { return (CloneGit @('rev-parse', $Revision))[0].Trim() }
function New-BaseTree([string] $Name, [string] $Commit) {
    $path = Join-Path $work "b-$Name"
    if (-not [IO.Directory]::Exists($path)) { [void](CloneGit @('worktree', 'add', '-q', '--detach', $path, $Commit)) }
    return $path
}
function Set-Head([string] $Commit) {
    [void](CloneGit @('checkout', '-q', '-f', '--detach', $Commit))
    [void](CloneGit @('clean', '-q', '-fdx'))
}
function Build-Head([string] $Set, [string] $Base, [string] $Kind, [switch] $Consume, [string] $Records, [string] $Label) {
    $arguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'New-IFXI2CPullRequestHeads.ps1'), '-Clone', $clone, '-Set', $Set, '-BaseCommit', $Base, '-Kind', $Kind, '-Branch', "rehearsal/$Label")
    if ($Consume) { $arguments += '-ConsumeRecords' }
    if ($Records) { $arguments += @('-RecordsDirectory', $Records) }
    $text = (& pwsh @arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Building $Label failed: $text" }
    $result = ($text.Split("`n") | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json -Depth 20
    $builds[$Label] = $result
    $commits[$Label] = [string]$result.head
    return [string]$result.head
}
function Merge-Into([string] $Base, [string] $Head, [string] $Label) {
    [void](CloneGit @('checkout', '-q', '-f', '-B', 'rehearsal/target', $Base))
    [void](CloneGit @('merge', '-q', '--no-ff', '-m', "rehearsal: merge $Label into $($spec.targetBranch)", $Head))
    $merged = Get-Commit 'HEAD'
    $commits["merged-$Label"] = $merged
    return $merged
}
function Invoke-Trusted([string] $Tree, [string] $Script, [string[]] $Arguments) {
    return Invoke-GuardIsolatedPwsh (Join-Path $Tree "docs/guards/V3_ifx/trusted-base/$Script") $Arguments -WorkingDirectory $clone
}
function Invoke-HeadScript([string] $Root, [string] $Relative, [string[]] $Arguments) {
    return Invoke-GuardIsolatedPwsh (Join-Path $Root $Relative) $Arguments -WorkingDirectory $Root
}
function Add-Step([string] $Id, [string] $Description, [string] $Base, [string] $Head, [int] $Expected, [object] $Run, [string] $ExpectText) {
    $script:stepNumber++
    $text = ($Run.Output -replace '\s+', ' ')
    $ok = $Run.ExitCode -eq $Expected -and (-not $ExpectText -or $text.Contains($ExpectText, [StringComparison]::Ordinal))
    $log = Join-Path $logs ('{0:D2}-{1}.log' -f $script:stepNumber, $Id)
    $clean = $Run.Output.Replace($work, '<work>').Replace($tempRoot, '<temp>')
    [IO.File]::WriteAllText($log, $clean, [Text.UTF8Encoding]::new($false))
    $evidence = @($clean -split "`n" | Where-Object { $_ -match '^FAIL |Protected change verification|Trusted base run|Trusted component candidate|Policy candidate validation|Cutover preservation|unexpected entry|not in the base commit|Uncovered|IFX guardrails|Passed!|Failed!' } | ForEach-Object { $_.Trim() } | Select-Object -Unique -First 14)
    $steps.Add([ordered]@{ id = $Id; description = $Description; base = $Base; head = $Head; expectedExit = $Expected; expectText = $ExpectText; exit = $Run.ExitCode; asExpected = $ok; log = [IO.Path]::GetRelativePath($output, $log).Replace('\', '/'); evidence = $evidence })
    Write-Host ("[{0}] {1}: exit {2} (expected {3})" -f $(if ($ok) { 'OK' } else { 'UNEXPECTED' }), $Id, $Run.ExitCode, $Expected)
}
function Get-SetSpec([string] $Set) { return @($spec.sets | Where-Object id -CEQ $Set)[0] }
function Get-PlanPath([string] $Set, [switch] $Authorization) {
    $plan = [string](Get-SetSpec $Set).plan
    if ($Authorization) { return $plan.Replace('.plan.json', '-authorization.plan.json') }
    return $plan
}
function Test-Gates([string] $Tag, [string] $Set, [string] $Base, [string] $Head, [switch] $Change, [switch] $Quality, [switch] $G03) {
    $tree = New-BaseTree $Tag $Base
    Set-Head $Head
    Add-Step "$Tag-diff" "$Set passes the trusted Diff with its formal plan." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Diff', '-PlanPath', (Get-PlanPath $Set), '-BaseRef', $Base, '-HeadRef', $Head, '-GateId', 'v3-pre-diff')) 'Trusted base run passed'
    if ($Change) {
        $parity = if ($QuickParity) { @('-ParityModes', 'HistoricalIntegrity') } else { @() }
        Add-Step "$Tag-candidates" "$Set trusted component change passes base-owned validation and parity." $Base $Head 0 (Invoke-Trusted $tree 'Test-IFXTrustedBaseCandidate.ps1' (@('-TargetRoot', $clone, '-BaseSha', $Base, '-HeadRevision', $Head) + $parity)) 'authorized change of'
        Add-Step "$Tag-policy-candidates" "$Set head policy candidates pass base validation." $Base $Head 0 (Invoke-Trusted $tree 'Test-IFXPolicyCandidates.ps1' @('-TargetRoot', $clone, '-BaseSha', $Base, '-HeadRevision', $Head, '-ReportPath', (Join-Path $work "$Tag-policy-candidates.json"))) 'Policy candidate validation passed'
    }
    Set-Head $Head
    Add-Step "$Tag-validate" "$Set passes Validate for its explicit head." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Validate', '-HeadRef', $Head, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    Set-Head $Head
    Add-Step "$Tag-candidate-tests" "$Set head candidate package tests pass (includes Test-CutoverPreservation)." $Base $Head 0 (Invoke-HeadScript $clone 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1' @('-Mode', 'CandidateTests', '-CandidateSuite', 'Architecture', '-TargetRoot', $clone)) ''
    Set-Head $Head
    Add-Step "$Tag-architecture" "$Set passes the production architecture scan." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Architecture', '-HeadRef', $Head, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    Set-Head $Head
    Add-Step "$Tag-historical" "$Set passes Historical Integrity." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'HistoricalIntegrity', '-GateId', 'v3-historical-integrity')) 'Trusted base run passed'
    if ($G03) {
        Set-Head $Head
        Add-Step "$Tag-g03" "$Set passes the G03 specialized gate." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Specialized', '-SpecializedGate', 'G03', '-HeadRef', $Head, '-GateId', 'v3-specialized-g03')) 'Trusted base run passed'
    }
    if ($Quality -and -not $SkipQuality) {
        Set-Head $Head
        Add-Step "$Tag-quality-solution" "$Set passes solution quality (build and tests)." $Base $Head 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Quality', '-QualityTarget', 'Solution', '-GateId', 'v3-quality-solution')) 'Trusted base run passed'
    }
}
function Invoke-TwoPr([string] $Set, [string] $Base, [string] $Tag) {
    $entry = Get-SetSpec $Set
    $tree = New-BaseTree "$Tag-base" $Base
    # the change opened before its records exist
    $early = Build-Head $Set $Base 'change' -Label "$Tag-early"
    Set-Head $early
    Add-Step "$Tag-early-diff" "$Set fails before its authorization PR merges." $Base $early 1 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Diff', '-PlanPath', (Get-PlanPath $Set), '-BaseRef', $Base, '-HeadRef', $early, '-GateId', 'v3-pre-diff')) 'Uncovered'
    # records generated by the base generator from the prepared change
    $recordDirectory = Join-Path $work "records-$Tag"
    [void][IO.Directory]::CreateDirectory($recordDirectory)
    foreach ($authorization in @($entry.authorizations)) {
        $generatorArguments = @('-Id', $authorization.id, '-Operation', $authorization.operation, '-BaseRevision', $Base, '-HeadRevision', $early, '-PlanPath', (Get-PlanPath $Set), '-DecisionPaths', (@($authorization.decisionPaths) -join ','), '-Repository', $clone, '-OutputPath', (Join-Path $recordDirectory "$($authorization.id).json"))
        if ($authorization.operation -ceq 'change-trusted-base') { $generatorArguments += @('-ParityContract', [string]$authorization.parityContract) }
        $run = Invoke-Trusted $tree 'New-IFXTrustedBaseAuthorization.ps1' $generatorArguments
        if ($run.ExitCode -ne 0) { throw "Authorization generator failed for $($authorization.id): $($run.Output)" }
        [void][IO.Directory]::CreateDirectory($recordsOut)
        [IO.File]::WriteAllText((Join-Path $recordsOut "$($authorization.id).json"), [IO.File]::ReadAllText((Join-Path $recordDirectory "$($authorization.id).json")).Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
    }
    # authorization PR
    $authorizationHead = Build-Head $Set $Base 'authorization' -Records $recordDirectory -Label "$Tag-authorization"
    Set-Head $authorizationHead
    Add-Step "$Tag-authorization-diff" "$Set authorization PR passes the trusted Diff." $Base $authorizationHead 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Diff', '-PlanPath', (Get-PlanPath $Set -Authorization), '-BaseRef', $Base, '-HeadRef', $authorizationHead, '-GateId', 'v3-pre-diff')) 'Trusted base run passed'
    Add-Step "$Tag-authorization-candidates" "$Set authorization PR changes no trusted component." $Base $authorizationHead 0 (Invoke-Trusted $tree 'Test-IFXTrustedBaseCandidate.ps1' @('-TargetRoot', $clone, '-BaseSha', $Base, '-HeadRevision', $authorizationHead)) 'no trusted component changes'
    Set-Head $authorizationHead
    Add-Step "$Tag-authorization-validate" "$Set authorization PR passes Validate." $Base $authorizationHead 0 (Invoke-Trusted $tree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $Base, '-Mode', 'Validate', '-HeadRef', $authorizationHead, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    $authorized = Merge-Into $Base $authorizationHead "$Tag-authorization"
    # change PR on the authorized base
    $change = Build-Head $Set $authorized 'change' -Consume -Label "$Tag-change"
    Test-Gates "$Tag-change" $Set $authorized $change -Change -G03
    $merged = Merge-Into $authorized $change "$Tag-change"
    return [ordered]@{ authorized = $authorized; change = $change; merged = $merged; records = $recordDirectory }
}
function Invoke-Allowlist([string] $Root, [string] $Id, [string] $Description, [int] $Expected, [string] $ExpectText, [scriptblock] $Mutate, [scriptblock] $Restore, [string] $Head) {
    & $Mutate
    try { Add-Step $Id $Description '' $Head $Expected (Invoke-HeadScript $Root 'docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1' @()) $ExpectText }
    finally { & $Restore }
}

$failed = $true
try {
    [void][IO.Directory]::CreateDirectory($work)
    [void][IO.Directory]::CreateDirectory($logs)
    $cloneOutput = @(& git -c core.longpaths=true clone -q --no-checkout $repositoryPath $clone 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Cannot clone the repository: $($cloneOutput -join ' ')" }
    [void](CloneGit @('config', 'core.longpaths', 'true'))
    $target0 = [string]$spec.initialTarget
    $commits['target'] = $target0
    Write-Host "Rehearsal target $target0 in $work"

    # ---- P1
    $p1 = Build-Head 'P1' $target0 'change' -Label 'p1'
    Test-Gates 'p1' 'P1' $target0 $p1 -Quality
    $target1 = Merge-Into $target0 $p1 'p1'

    # ---- P2 (P2a, P2)
    $p2 = Invoke-TwoPr 'P2' $target1 'p2'
    $target2 = $p2.merged

    # ---- P3 (P3a, P3)
    $p3 = Invoke-TwoPr 'P3' $target2 'p3'
    $target3 = $p3.merged

    # ---- P3 allowlist controls on the change head, and the unchanged base test
    Set-Head $p3.change
    $guards = Join-Path $clone 'docs/guards'
    Invoke-Allowlist $clone 'p3-allowlist-positive' 'The new allowlist passes on the P3 head.' 0 'Cutover preservation passed' {} {} $p3.change
    Invoke-Allowlist $clone 'p3-allowlist-extra-entry' 'An additional docs/guards entry fails.' 1 'unexpected entry' { [void][IO.Directory]::CreateDirectory((Join-Path $guards 'candidates')); [IO.File]::WriteAllText((Join-Path $guards 'candidates/x.md'), "x`n") } { Remove-Item -LiteralPath (Join-Path $guards 'candidates') -Recurse -Force } $p3.change
    Invoke-Allowlist $clone 'p3-allowlist-case' 'A differently cased v4-adoption entry fails.' 1 'unexpected entry' { Rename-Item -LiteralPath (Join-Path $guards 'v4-adoption') 'case-tmp'; Rename-Item -LiteralPath (Join-Path $guards 'case-tmp') 'V4-Adoption' } { Rename-Item -LiteralPath (Join-Path $guards 'V4-Adoption') 'case-tmp'; Rename-Item -LiteralPath (Join-Path $guards 'case-tmp') 'v4-adoption' } $p3.change
    Invoke-Allowlist $clone 'p3-allowlist-missing' 'A missing v4-adoption entry fails.' 1 'unexpected entry' { Move-Item -LiteralPath (Join-Path $guards 'v4-adoption') (Join-Path $work 'moved-v4-adoption') } { Move-Item -LiteralPath (Join-Path $work 'moved-v4-adoption') (Join-Path $guards 'v4-adoption') } $p3.change
    $baseTree = New-BaseTree 'p3-unchanged-test' $target2
    $baseGuards = Join-Path $baseTree 'docs/guards'
    Invoke-Allowlist $baseTree 'p3-base-test-rejects' 'The unchanged base test rejects a v4-adoption entry.' 1 'unexpected entry' { [void][IO.Directory]::CreateDirectory((Join-Path $baseGuards 'v4-adoption')); [IO.File]::WriteAllText((Join-Path $baseGuards 'v4-adoption/README.md'), "x`n") } { Remove-Item -LiteralPath (Join-Path $baseGuards 'v4-adoption') -Recurse -Force } $target2

    # ---- replay: a second PR cannot consume the consumed trusted-base record
    $record = "$authorizationDirectory/i2c-v4-adoption-admission-trusted-base.json"
    [void](CloneGit @('checkout', '-q', '-f', '-B', 'rehearsal/replay', $p3.authorized))
    $testPath = Join-Path $clone 'docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1'
    [IO.File]::WriteAllText($testPath, "# replay`n" + [IO.File]::ReadAllText($testPath), [Text.UTF8Encoding]::new($false))
    [void](CloneGit @('rm', '-q', '--', $record))
    $replayPlan = [ordered]@{ formatVersion = 1; id = '20261001-v4-ifx-i2c-replay'; title = 'Rehearsal replay'; goal = 'Try to consume a consumed record.'; acceptanceCriteria = @('The trusted Diff rejects the replay.'); plannedPaths = @($record, 'docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1', 'docs/guards/plans/20261001-v4-ifx-i2c-replay.md', 'docs/guards/plans/20261001-v4-ifx-i2c-replay.plan.json'); areaIds = @('GuardDocs', 'GuardPackage'); ruleIds = @(); validationCommands = @('ifx-package-test'); decisionPaths = @('docs/guards/V3_ifx/shared/decisions/history/20260916-v3-stage-d10-protected-change-authorization.json') }
    [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/plans/20261001-v4-ifx-i2c-replay.plan.json'), ($replayPlan | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/plans/20261001-v4-ifx-i2c-replay.md'), "# Rehearsal replay`n", [Text.UTF8Encoding]::new($false))
    [void](CloneGit @('add', '-A'))
    [void](CloneGit @('commit', '-q', '-m', 'rehearsal: replay a consumed record'))
    $replay = Get-Commit 'HEAD'
    $commits['p3-replay'] = $replay
    $mergedTree = New-BaseTree 'p3-merged' $target3
    Set-Head $replay
    Add-Step 'p3-replay-diff' 'A second PR cannot consume the record that P3 already consumed.' $target3 $replay 1 (Invoke-Trusted $mergedTree 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $target3, '-Mode', 'Diff', '-PlanPath', 'docs/guards/plans/20261001-v4-ifx-i2c-replay.plan.json', '-BaseRef', $target3, '-HeadRef', $replay, '-GateId', 'v3-pre-diff')) 'not in the base commit'

    # ---- final state of the simulated target
    $treeLines = CloneGit @('ls-tree', '--name-only', "${target3}:docs/guards")
    $topLevel = @(foreach ($line in $treeLines) { ([string]$line).Trim() }) | Sort-Object -CaseSensitive
    $adoptionLines = CloneGit @('ls-tree', '-r', '--name-only', "${target3}:docs/guards/v4-adoption")
    $adoption = @(foreach ($line in $adoptionLines) { ([string]$line).Trim() })
    $recordLines = CloneGit @('ls-tree', '--name-only', "${target3}:$authorizationDirectory")
    $remainingRecords = @(foreach ($line in $recordLines) { $name = ([string]$line).Trim(); if ($name -like '*.json') { $name } })
    # Each path must end in the blob of the last set that writes it: copied paths equal the development branch, authored
    # paths (P3's policy-config.json supersedes P2's copy) equal their authored file.
    $finalOwner = [ordered]@{}
    foreach ($entry in @($spec.sets)) {
        foreach ($path in @($entry.copy)) { $finalOwner[$path] = [ordered]@{ kind = 'copy'; set = $entry.id } }
        foreach ($path in @($entry.authored)) { $finalOwner[$path] = [ordered]@{ kind = 'authored'; set = $entry.id } }
    }
    $blobMismatches = @(foreach ($path in $finalOwner.Keys) {
            $owner = $finalOwner[$path]
            $want = if ($owner.kind -ceq 'copy') { (Invoke-IFXI2CGit $repositoryPath @('rev-parse', "$($spec.sourceCommit):$path"))[0].Trim() }
            else { (CloneGit @('hash-object', "--path=$path", (Join-Path $PSScriptRoot "pr/$($owner.set)/$path")))[0].Trim() }
            $have = (CloneGit @('rev-parse', "${target3}:$path"))[0].Trim()
            if ($want -cne $have) { $path } })
    $finalState = [ordered]@{
        target = $target3
        docsGuardsTopLevel = $topLevel
        v4AdoptionFiles = $adoption
        remainingAuthorizationRecords = $remainingRecords
        finalBlobMismatches = $blobMismatches
        checkedPaths = @($finalOwner.Keys)
        pass = (($topLevel -join ',') -ceq 'V3,V3_ifx,plans,v4-adoption') -and (($adoption -join ',') -ceq 'README.md') -and $remainingRecords.Count -eq 0 -and $blobMismatches.Count -eq 0
    }
    $unexpected = @($steps | Where-Object { -not $_.asExpected })
    $failed = $unexpected.Count -gt 0 -or -not $finalState.pass
    $records = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $recordsOut -Filter '*.json' -File | Sort-Object Name)) {
        $records["$authorizationDirectory/$($file.Name)"] = [ordered]@{ sha256 = Get-IFXI2CFileSha256 $file.FullName; record = (Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 50) }
    }
    $report = [ordered]@{
        formatVersion = 1
        kind = 'ifx-i2c-rehearsal'
        planId = '20261001-v4-ifx-i2c-main-promotion'
        step = 'C3'
        status = if ($failed) { 'fail' } else { 'pass' }
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        repositoryHead = (Invoke-IFXI2CGit $repositoryPath @('rev-parse', 'HEAD'))[0].Trim()
        specSha256 = Get-IFXI2CFileSha256 (Join-Path $PSScriptRoot 'pr-spec.json')
        sourceCommit = [string]$spec.sourceCommit
        parity = if ($QuickParity) { 'HistoricalIntegrity' } else { 'full fixed corpus' }
        qualitySolution = -not $SkipQuality
        notRunLocally = @('v3-quality-assembly', 'v3-quality-frontend', 'v3-specialized-g04', 'v3-specialized-g05', 'v3-specialized-plan04', 'v3-specialized-database', 'v3-cross-platform-ubuntu-latest', 'v3-cross-platform-windows-latest (candidate suite)')
        commits = $commits
        builds = $builds
        records = $records
        steps = @($steps)
        unexpectedSteps = @($unexpected | ForEach-Object id)
        finalState = $finalState
        note = 'Rehearsal commits are local and are never pushed; C5-C7 rebuild each head on the real target head and regenerate the records, which may differ from these only in base identities.'
    }
    Write-IFXI2CJson (Join-Path $output 'rehearsal.json') $report
    Write-Host "C3 rehearsal $($report.status): $(Join-Path $output 'rehearsal.json')"
}
finally {
    if (-not $KeepWorkDirectory -and [IO.Directory]::Exists($work)) {
        foreach ($tree in @(Get-ChildItem -LiteralPath $work -Directory -Filter 'b-*')) { [void](& git -C $clone worktree remove --force $tree.FullName 2>&1) }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($failed) { exit 1 }
