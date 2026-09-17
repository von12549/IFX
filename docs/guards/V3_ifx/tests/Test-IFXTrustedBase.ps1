[CmdletBinding()]
param(
    [switch] $KeepWorkDirectory,
    # Runs only the trusted build isolation control, which builds LayerGuard (Plan 06 §11.2, P2.5).
    [switch] $ArchitectureOnly,
    # Runs only the end-to-end Diff and protected change verifier controls for authorization consumption (D20, D22, D23).
    [switch] $DiffConsumptionOnly
)

# Plan 06 P2.5 and P2.7 negative controls for trusted base execution (§11.1, §11.5, §12.6), outside the repository:
#  - a disposable clone commits the current package as the base; the base runs from a separate worktree;
#  - head branches tamper with the dispatcher, engine, policy, module and MSBuild inheritance, change domain
#    authorities, or change trusted components with and without a consumed base authorization.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
Import-Module (Join-Path $package 'trusted-base/TrustedBase.psm1') -Force
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$work = Get-GuardFullPath (Join-Path $tempRoot "ifxtb-$([Guid]::NewGuid().ToString('N').Substring(0, 8))")
if (Test-GuardPathWithin $work $repository) { throw 'The trusted base fixture must be outside the repository.' }
$clone = Join-Path $work 'h'
$utf8 = [Text.UTF8Encoding]::new($false)
$failures = [Collections.Generic.List[string]]::new()
$gitIdentity = @('-c', 'user.name=guard-fixture', '-c', 'user.email=guard-fixture@example.invalid', '-c', 'commit.gpgsign=false')

function Invoke-FixtureGit([string] $Repository, [string[]] $Arguments) {
    $output = @(& git -C $Repository @gitIdentity @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join ' | ')" }
    return , $output
}
function Edit-Text([string] $Relative, [scriptblock] $Change) {
    $path = Join-Path $clone $Relative
    [IO.File]::WriteAllText($path, (& $Change ([IO.File]::ReadAllText($path))), $utf8)
}
function Edit-Json([string] $Relative, [scriptblock] $Change) {
    $path = Join-Path $clone $Relative
    $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    & $Change $document
    [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8)
}
function New-Head([string] $Name, [string] $From, [scriptblock] $Edits) {
    [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', '-B', $Name, $From))
    & $Edits
    [void](Invoke-FixtureGit $clone @('add', '-A'))
    [void](Invoke-FixtureGit $clone @('commit', '-q', '--allow-empty', '-m', $Name))
    return (Invoke-FixtureGit $clone @('rev-parse', 'HEAD'))[0]
}
function New-BaseWorktree([string] $Name, [string] $Commit) {
    $path = Join-Path $work $Name
    [void](Invoke-FixtureGit $clone @('worktree', 'add', '-q', '--detach', $path, $Commit))
    return $path
}
function Invoke-Runner([string] $Base, [string] $BaseSha, [string] $Mode, [string[]] $Extra = @()) {
    $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1'
    return Invoke-GuardIsolatedPwsh $script (@('-HeadRoot', $clone, '-BaseSha', $BaseSha, '-Mode', $Mode) + $Extra) -WorkingDirectory $clone
}
function Invoke-Verifier([string] $Base, [string] $BaseSha) {
    $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1'
    return Invoke-GuardIsolatedPwsh $script @('-TargetRoot', $clone, '-BaseSha', $BaseSha, '-ParityModes', 'HistoricalIntegrity') -WorkingDirectory $clone
}
function Assert-Result([string] $Label, [object] $Result, [int] $Expected, [string] $ExpectText) {
    $text = ($Result.Output -replace '\s+', ' ')
    if ($Result.ExitCode -ne $Expected) { $failures.Add("$Label expected exit $Expected, got $($Result.ExitCode): $(($Result.Output -split "`n" | Select-Object -Last 12) -join ' | ')"); return }
    if ($ExpectText -and -not $text.Contains(($ExpectText -replace '\s+', ' '), [StringComparison]::Ordinal)) { $failures.Add("$Label did not report '$ExpectText': $(($Result.Output -split "`n" | Select-Object -Last 12) -join ' | ')"); return }
    Write-Host "PASS $Label"
}

$evidence = 'mcp/LayerGuard/baselines/b1.json'
$historyEngine = 'docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1'
$historyTest = 'docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1'
$catalog = 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
$breakEvidence = { Edit-Json $evidence { param($d) $d['fixtureTamper'] = $true } }

try {
    # ---- base commit: the current package (including uncommitted work) on top of HEAD
    [void][IO.Directory]::CreateDirectory($work)
    $headCommit = (Invoke-FixtureGit $repository @('rev-parse', 'HEAD'))[0]
    [void](Invoke-FixtureGit $work @('clone', '-q', '--shared', '--no-checkout', $repository, $clone))
    [void](Invoke-FixtureGit $clone @('checkout', '-q', '--detach', $headCommit))
    $pending = @(Invoke-GuardGitNul $repository @('diff', '--name-only', '-z', 'HEAD')) + @(Invoke-GuardGitNul $repository @('ls-files', '-z', '--others', '--exclude-standard'))
    foreach ($relative in $pending) {
        if ([IO.File]::Exists((Join-Path $repository $relative))) { Copy-GuardFiles $repository $clone @($relative) }
        elseif ([IO.File]::Exists((Join-Path $clone $relative))) { [IO.File]::Delete((Join-Path $clone $relative)) }
    }
    [void](Invoke-FixtureGit $clone @('add', '-A'))
    [void](Invoke-FixtureGit $clone @('commit', '-q', '--allow-empty', '-m', 'fixture base'))
    $baseSha = (Invoke-FixtureGit $clone @('rev-parse', 'HEAD'))[0]
    $base = New-BaseWorktree 'b' $baseSha
    Write-Host "Fixture base $baseSha at $base"

    if ($ArchitectureOnly) {
        # §11.1/§11.2: head MSBuild inheritance files cannot reach trusted guard builds, whose output stays outside head.
        [void](New-Head 'architecture-injection' $baseSha {
            [IO.File]::WriteAllText((Join-Path $clone 'Directory.Build.props'), "<Project><Target Name=`"InjectedFailure`" BeforeTargets=`"Restore;Build;VSTest`"><Error Text=`"head injection`" /></Target></Project>`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $clone 'Directory.Build.targets'), "<Project><Target Name=`"InjectedTargets`" AfterTargets=`"Build`"><Error Text=`"head targets injection`" /></Target></Project>`n", $utf8)
            [IO.File]::WriteAllText((Join-Path $clone 'Directory.Packages.props'), "<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally><NuGetAudit>false</NuGetAudit></PropertyGroup></Project>`n", $utf8)
        })
        Assert-Result 'head MSBuild injection does not reach the trusted architecture build' (Invoke-Runner $base $baseSha 'Architecture' @('-GateId', 'v3-architecture')) 0 'Trusted base run passed'
        $isolation = @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-architecture.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'trusted-build-isolation' })
        if ($isolation.Count -ne 1 -or $isolation[0].status -ne 'pass' -or [IO.Directory]::Exists((Join-Path $clone 'artifacts/build/v3-ifx'))) { $failures.Add("Trusted guard build output reached the head checkout: $($isolation | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS trusted guard build output stays outside the head checkout' }
        if ($failures.Count -gt 0) { foreach ($failure in $failures) { Write-Host "FAIL $failure" }; exit 1 }
        Write-Host 'IFX trusted base architecture isolation test passed.'
        return
    }

    if ($DiffConsumptionOnly) {
        # Plan 06 §12.3 with D22 and D23: the trusted Diff exempts only deletions that the base protected change verifier
        # covered with base authorizations deleted by head; every other protected deletion, and any report or variable
        # that head or the caller supplies, stays blocked. Runner cases build the Diff stage; verifier cases check the
        # obligation rules directly.
        $authorizations = 'docs/guards/V3_ifx/stages/diff/authorizations'
        $changePlan = 'docs/guards/plans/20260917-fixture-change.plan.json'
        $decision = 'docs/guards/V3_ifx/decisions/history/20260917-v3-stage-d19-trusted-base-first-introduction.json'
        $backupFile = 'docs/guards/V3_backup/README.md'
        $backupDirectory = 'docs/guards/V3_backup/architecture'
        $engineComment = { Edit-Text $historyEngine { param($t) $t.Replace("`$ErrorActionPreference = 'Stop'", "# fixture: behaviour-equivalent change`n`$ErrorActionPreference = 'Stop'") } }
        $deleteBackupFile = { [void](Invoke-FixtureGit $clone @('rm', '-q', $backupFile)) }
        $moveBackupDirectory = { [void](Invoke-FixtureGit $clone @('mv', $backupDirectory, 'docs/guards/V3_backup/design')) }
        $caseRenameBackupDirectory = {
            [void](Invoke-FixtureGit $clone @('mv', $backupDirectory, 'docs/guards/V3_backup/architecture-case'))
            [void](Invoke-FixtureGit $clone @('mv', 'docs/guards/V3_backup/architecture-case', 'docs/guards/V3_backup/Architecture'))
        }

        function New-PlannedHead([string] $Name, [string] $From, [scriptblock] $Edits, [scriptblock] $Staged) {
            [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', '-B', $Name, $From))
            & $Edits
            [void](Invoke-FixtureGit $clone @('add', '-A'))
            [string[]] $planned = Invoke-FixtureGit $clone @('diff', '--cached', '--no-renames', '--name-only', $From)
            $planFile = Join-Path $clone $changePlan
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($planFile))
            $plan = [ordered]@{
                formatVersion = 1; id = '20260917-fixture-change'; title = "Fixture $Name"; goal = 'Exercise protected change authorization in the trusted Diff.'
                acceptanceCriteria = @('The trusted Diff verdict matches the expected authorization outcome.')
                plannedPaths = @($planned | Sort-Object); areaIds = @('CI', 'GuardDocs', 'GuardPackage'); ruleIds = @(); validationCommands = @('ifx-package-test')
                decisionPaths = @($decision, 'docs/guards/V3_ifx/decisions/history/20260916-v3-stage-d10-protected-change-authorization.json', 'docs/guards/V3_ifx/decisions/history/20260916-v3-stage-d02-v3-backup-retirement.json', 'docs/guards/V3_ifx/decisions/history/20260917-v3-stage-d24-policy-config-dual-track.json')
            }
            [IO.File]::WriteAllText($planFile, ($plan | ConvertTo-Json -Depth 5), $utf8)
            [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/plans/20260917-fixture-change.md'), "# Fixture $Name`n", $utf8)
            [void](Invoke-FixtureGit $clone @('add', '-A'))
            # Index-only entries such as gitlinks are staged after 'add -A', which would drop them.
            if ($Staged) { & $Staged }
            [void](Invoke-FixtureGit $clone @('commit', '-q', '-m', $Name))
            return (Invoke-FixtureGit $clone @('rev-parse', 'HEAD'))[0]
        }
        function New-Record([string] $Id, [string] $Prepared, [string[]] $Arguments) {
            $file = Join-Path $work "$Id.json"
            $helper = Invoke-GuardIsolatedPwsh (Join-Path $base 'docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1') (@('-Id', $Id, '-BaseRevision', $baseSha, '-HeadRevision', $Prepared, '-PlanPath', $changePlan, '-DecisionPaths', $decision, '-Repository', $clone, '-OutputPath', $file) + $Arguments) -WorkingDirectory $clone
            if ($helper.ExitCode -ne 0) { throw "Authorization helper failed for ${Id}: $($helper.Output)" }
            return $file
        }
        function New-AuthorizedBase([string] $Name, [string] $From, [string[]] $Records) {
            return New-Head $Name $From {
                [void][IO.Directory]::CreateDirectory((Join-Path $clone $authorizations))
                foreach ($record in $Records) { [IO.File]::Copy($record, (Join-Path $clone "$authorizations/$([IO.Path]::GetFileName($record))"), $true) }
            }
        }
        function Remove-Record([string] $Id) { [IO.File]::Delete((Join-Path $clone "$authorizations/$Id.json")) }
        function Invoke-TrustedDiff([string] $Base, [string] $BaseSha, [string] $HeadSha, [hashtable] $Environment = @{}) {
            $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1'
            return Invoke-GuardIsolatedPwsh $script @('-HeadRoot', $clone, '-BaseSha', $BaseSha, '-Mode', 'Diff', '-PlanPath', $changePlan, '-BaseRef', $BaseSha, '-HeadRef', $HeadSha, '-GateId', 'v3-pre-diff') -WorkingDirectory $clone -Environment $Environment
        }
        function Invoke-ProtectedVerifier([string] $Base, [string] $BaseSha, [string] $HeadSha) {
            $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Test-IFXProtectedChanges.ps1'
            return Invoke-GuardIsolatedPwsh $script @('-TargetRoot', $clone, '-BaseSha', $BaseSha, '-HeadRevision', $HeadSha, '-PlanPath', $changePlan, '-ReportPath', (Join-Path $work 'protected-changes.json')) -WorkingDirectory $clone
        }
        function Invoke-PolicyCandidates([string] $Base, [string] $BaseSha, [string] $HeadSha) {
            $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Test-IFXPolicyCandidates.ps1'
            return Invoke-GuardIsolatedPwsh $script @('-TargetRoot', $clone, '-BaseSha', $BaseSha, '-HeadRevision', $HeadSha, '-ReportPath', (Join-Path $work 'policy-candidates.json')) -WorkingDirectory $clone
        }
        function Get-DiffCheck {
            return @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'protected-changes' })
        }

        # ---- records generated from prepared changes, then committed to one authorized base
        $tcbRecord = New-Record 'fixture-consumption' (New-Head 'prepare-consumption' $baseSha $engineComment) @('-ParityContract', 'Fixture: verdicts unchanged on the fixed corpus.')
        $deleteRecord = New-Record 'fixture-delete' (New-Head 'prepare-delete' $baseSha $deleteBackupFile) @('-Operation', 'delete', '-SourcePath', $backupFile)
        $moveRecord = New-Record 'fixture-move' (New-Head 'prepare-move' $baseSha $moveBackupDirectory) @('-Operation', 'move', '-SourcePath', $backupDirectory, '-DestinationPath', 'docs/guards/V3_backup/design')
        $caseRecord = New-Record 'fixture-case-rename' (New-Head 'prepare-case-rename' $baseSha $caseRenameBackupDirectory) @('-Operation', 'case-rename', '-SourcePath', $backupDirectory, '-DestinationPath', 'docs/guards/V3_backup/Architecture')
        $duplicateRecord = Join-Path $work 'fixture-delete-again.json'
        $duplicate = Get-Content -LiteralPath $deleteRecord -Raw | ConvertFrom-Json -AsHashtable -Depth 20
        $duplicate.id = 'fixture-delete-again'
        [IO.File]::WriteAllText($duplicateRecord, ($duplicate | ConvertTo-Json -Depth 20), $utf8)
        $weakenRecord = Join-Path $work 'fixture-weaken.json'
        $weaken = [ordered]@{ formatVersion = 1; id = 'fixture-weaken'; operation = 'weaken-policy'; planPath = $changePlan; decisionPaths = @($decision); changedPaths = @($backupFile)
            policies = @([ordered]@{ path = $backupFile; baseSha256 = ('a' * 64); headSha256 = ('b' * 64); schema = 'contracts/profile.schema.json'; pointers = @('/rules'); head = [ordered]@{ mode = '100644'; type = 'blob'; objectId = ('c' * 40) } }) }
        [IO.File]::WriteAllText($weakenRecord, ($weaken | ConvertTo-Json -Depth 20), $utf8)
        $ruleFile = 'docs/guards/V3_ifx/profiles/ifx/rules/L1.2.json'
        $staleRuleTitle = { Edit-Text $ruleFile { param($t) $t.Replace('"No legacy Abstractions project"', '"No legacy Abstractions projects"') } }
        $ruleTitle = {
            & $staleRuleTitle
            $render = Invoke-GuardIsolatedPwsh (Join-Path $base 'docs/guards/V3_ifx/scripts/Invoke-V3Docs.ps1') @('-Mode', 'Render', '-ProfileDirectory', (Join-Path $clone 'docs/guards/V3_ifx/profiles/ifx'), '-TargetRoot', $clone) -WorkingDirectory $clone
            if ($render.ExitCode -ne 0) { throw "Profile view rendering failed: $($render.Output)" }
        }
        $newRule = { [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_ifx/profiles/ifx/rules/L9.9.json'), ([IO.File]::ReadAllText((Join-Path $clone $ruleFile)).Replace('"L1.2"', '"L9.9"').Replace('ruleRefs[L1.2]', 'ruleRefs[L9.9]')), $utf8) }
        $gitattributesEdit = { [IO.File]::AppendAllText((Join-Path $clone '.gitattributes'), "*.fixture text eol=lf`n") }
        $stageEdit = { Edit-Json 'docs/guards/V3_ifx/stages/diff/stage.json' { param($d) $d.gates[0].trustContract.guarantee = $d.gates[0].trustContract.guarantee + ' Fixture.' } }
        $ruleRecord = New-Record 'fixture-rule' (New-Head 'prepare-rule' $baseSha $ruleTitle) @('-Operation', 'weaken-policy')
        $newRuleRecord = New-Record 'fixture-new-rule' (New-Head 'prepare-new-rule' $baseSha $newRule) @('-Operation', 'weaken-policy')
        $gitattributesRecord = New-Record 'fixture-gitattributes' (New-Head 'prepare-gitattributes' $baseSha $gitattributesEdit) @('-Operation', 'weaken-policy')
        $stagePrepared = New-Head 'prepare-stage' $baseSha $stageEdit
        $stageTcbRecord = New-Record 'fixture-stage-tcb' $stagePrepared @('-ParityContract', 'Fixture: verdicts unchanged on the fixed corpus.')
        $stageWeakenRecord = New-Record 'fixture-stage-weaken' $stagePrepared @('-Operation', 'weaken-policy')
        $waiverEdit = { Edit-Json $catalog { param($d) $d.waivers += [ordered]@{ id = 'fixture-waiver' } } }
        $waiverRecord = New-Record 'fixture-waiver' (New-Head 'prepare-waiver' $baseSha $waiverEdit) @('-Operation', 'weaken-policy')
        $authorizedBase = New-AuthorizedBase 'authorize' $baseSha @($tcbRecord, $deleteRecord, $moveRecord, $caseRecord, $weakenRecord, $ruleRecord, $newRuleRecord, $gitattributesRecord, $stageTcbRecord, $stageWeakenRecord, $waiverRecord)
        $authorizedWorktree = New-BaseWorktree 'b-authorized' $authorizedBase
        $recordPath = "$authorizations/fixture-consumption.json"

        # ---- runner: exemptions reach the Diff stage only through the base verifier's bound report
        $consume = New-PlannedHead 'consume' $authorizedBase { & $engineComment; Remove-Record 'fixture-consumption' }
        Assert-Result 'trusted Diff accepts the deletion of the exactly consumed authorization' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $consume) 0 'Trusted base run passed'
        $check = Get-DiffCheck
        if ($check.Count -ne 1 -or $check[0].status -ne 'pass' -or -not ([string]$check[0].reason).Contains("$recordPath (consumed)")) { $failures.Add("Diff summary does not report the verified consumption: $($check | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS Diff summary reports the verified consumption' }
        Assert-Result 'candidate verification accepts the consuming change' (Invoke-GuardIsolatedPwsh (Join-Path $authorizedWorktree 'docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1') @('-TargetRoot', $clone, '-BaseSha', $authorizedBase, '-ParityModes', 'HistoricalIntegrity') -WorkingDirectory $clone) 0 'authorized change of tcb.engine.historical-integrity'

        $deleteHead = New-PlannedHead 'consume-delete' $authorizedBase { & $deleteBackupFile; Remove-Record 'fixture-delete' }
        Assert-Result 'trusted Diff accepts an authorized protected deletion' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $deleteHead) 0 'Trusted base run passed'

        $unauthorized = New-PlannedHead 'unauthorized-deletion' $authorizedBase { [void](Invoke-FixtureGit $clone @('rm', '-q', 'docs/guards/V3_ifx/README.md')) }
        $forged = Join-Path $work 'forged-report.json'
        [IO.File]::WriteAllText($forged, ([ordered]@{ formatVersion = 1; check = 'protected-changes'; status = 'pass'; allowedDeletions = @('docs/guards/V3_ifx/README.md') } | ConvertTo-Json), $utf8)
        Assert-Result 'a caller-supplied report does not reach the trusted Diff' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $unauthorized @{ GUARD_PROTECTED_CHANGES = $forged; GUARD_CONSUMED_AUTHORIZATIONS = 'docs/guards/V3_ifx/README.md' }) 1 'Protected guard deletions: docs/guards/V3_ifx/README.md'

        $revoke = New-PlannedHead 'revoke-only' $authorizedBase { Remove-Record 'fixture-consumption'; Remove-Record 'fixture-weaken' }
        Assert-Result 'a revocation-only change passes (D22)' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $revoke) 0 'Trusted base run passed'
        $check = Get-DiffCheck
        if ($check.Count -ne 1 -or -not ([string]$check[0].reason).Contains("$recordPath (revoked)")) { $failures.Add("Diff summary does not report the revocation: $($check | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS Diff summary reports the revocation' }

        $mixed = New-PlannedHead 'revoke-mixed' $authorizedBase { Remove-Record 'fixture-consumption'; Edit-Text 'README.md' { param($t) $t + "`nfixture`n" } }
        Assert-Result 'a revocation mixed with another change fails' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $mixed) 1 'covers no protected change of this pull request'

        $mismatch = New-PlannedHead 'consume-mismatch' $authorizedBase { & $engineComment; Edit-Text $historyEngine { param($t) $t + "`n# unauthorized extra change`n" }; Remove-Record 'fixture-consumption' }
        Assert-Result 'a change that differs from the authorization keeps the deletion blocked' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $mismatch) 1 "Protected guard deletions: $recordPath"

        $extra = New-PlannedHead 'consume-plus-protected-deletion' $authorizedBase { & $engineComment; Remove-Record 'fixture-consumption'; [void](Invoke-FixtureGit $clone @('rm', '-q', 'docs/guards/V3_ifx/README.md')) }
        Assert-Result 'consumption does not exempt another protected deletion' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $extra) 1 'Protected guard deletions: docs/guards/V3_ifx/README.md'

        $renamed = New-PlannedHead 'consume-by-rename' $authorizedBase { & $engineComment; [void](Invoke-FixtureGit $clone @('mv', $recordPath, "$authorizations/fixture-renamed.json")) }
        Assert-Result 'renaming the consumed authorization fails' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $renamed) 1 'Authorization file name must equal its id'

        # ---- verifier: path operations
        Assert-Result 'authorized directory move passes' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'consume-move' $authorizedBase { & $moveBackupDirectory; Remove-Record 'fixture-move' })) 0 'obligation(s) covered'
        Assert-Result 'authorized case-only rename passes' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'consume-case' $authorizedBase { & $caseRenameBackupDirectory; Remove-Record 'fixture-case-rename' })) 0 'obligation(s) covered'
        Assert-Result 'a case-only rename consumed as a move fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'case-as-move' $authorizedBase { & $caseRenameBackupDirectory; Remove-Record 'fixture-move' })) 1 'Uncovered protected-removal'
        Assert-Result 'an undeclared case-only rename fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'case-undeclared' $authorizedBase { & $caseRenameBackupDirectory })) 1 'Uncovered protected-removal needs a base authorization'
        Assert-Result 'an extra file under the move destination fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'move-extra' $authorizedBase { & $moveBackupDirectory; [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_backup/design/extra.md'), "extra`n", $utf8); Remove-Record 'fixture-move' })) 1 'changed paths differ from the authorization'
        Assert-Result 'a delete authorization does not cover a case-only rename' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'delete-kept-case' $authorizedBase { [void](Invoke-FixtureGit $clone @('mv', $backupFile, 'docs/guards/V3_backup/readme.md')); Remove-Record 'fixture-delete' })) 1 'differs from docs/guards/V3_backup/README.md only in case'

        $changedBase = New-Head 'authorize-after-edit' $authorizedBase { Edit-Text $backupFile { param($t) $t + "`nchanged after authorization`n" } }
        $changedWorktree = New-BaseWorktree 'b-changed' $changedBase
        Assert-Result 'a deletion whose source changed after authorization fails' (Invoke-ProtectedVerifier $changedWorktree $changedBase (New-PlannedHead 'delete-changed' $changedBase { & $deleteBackupFile; Remove-Record 'fixture-delete' })) 1 'does not match its base tree entry'

        # ---- verifier: candidate set rules
        $duplicateBase = New-AuthorizedBase 'authorize-duplicate' $authorizedBase @($duplicateRecord)
        $duplicateWorktree = New-BaseWorktree 'b-duplicate' $duplicateBase
        Assert-Result 'an obligation covered by two authorizations fails' (Invoke-ProtectedVerifier $duplicateWorktree $duplicateBase (New-PlannedHead 'delete-twice' $duplicateBase { & $deleteBackupFile; Remove-Record 'fixture-delete'; Remove-Record 'fixture-delete-again' })) 1 'is covered by more than one authorization'
        Assert-Result 'a weaken-policy authorization without a matching policy change fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'consume-weaken' $authorizedBase { & $deleteBackupFile; Remove-Record 'fixture-delete'; Remove-Record 'fixture-weaken' })) 1 'has no semantic policy change in this pull request'
        Assert-Result 'an authorization that exists only in head fails' (Invoke-ProtectedVerifier $base $baseSha (New-PlannedHead 'head-only' $baseSha { & $deleteBackupFile; [IO.File]::Copy($deleteRecord, (Join-Path $clone "$authorizations/fixture-delete.json"), $true) })) 1 'Uncovered protected-removal'
        Assert-Result 'a protected deletion that keeps its authorization fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'delete-keep-record' $authorizedBase $deleteBackupFile)) 1 'Uncovered protected-removal'
        Assert-Result 'an unused path authorization fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'unused-move' $authorizedBase { & $engineComment; Remove-Record 'fixture-consumption'; Remove-Record 'fixture-move' })) 1 'fixture-move.json is rejected: the record covers no protected change'

        $consumedBase = New-Head 'merge-first-consumer' $authorizedBase { & $deleteBackupFile; Remove-Record 'fixture-delete' }
        $consumedWorktree = New-BaseWorktree 'b-consumed' $consumedBase
        Assert-Result 'a second pull request consuming the same authorization fails' (Invoke-ProtectedVerifier $consumedWorktree $consumedBase $deleteHead) 1 'the record is not in the base commit'

        Assert-Result 'changing an authorization record fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'edit-record' $authorizedBase { Edit-Json "$authorizations/fixture-move.json" { param($d) $d.planPath = 'README.md' } })) 1 'Authorization records are immutable'
        Assert-Result 'adding a schema-invalid authorization fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'add-invalid' $authorizedBase { [IO.File]::WriteAllText((Join-Path $clone "$authorizations/fixture-invalid.json"), '{"formatVersion":1,"id":"fixture-invalid","operation":"rename"}', $utf8) })) 1 'Added authorization does not match its schema'
        Assert-Result 'a gitlink in the protected scope fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'gitlink' $authorizedBase { Edit-Text 'README.md' { param($t) $t + "`nfixture`n" } } { [void](Invoke-FixtureGit $clone @('update-index', '--add', '--cacheinfo', "160000,$authorizedBase,docs/guards/V3_backup/module")) })) 1 'Gitlink (mode 160000) in the protected scope: docs/guards/V3_backup/module'

        # ---- policy and configuration obligations and head candidates (D24)
        $ruleHead = New-PlannedHead 'consume-rule' $authorizedBase { & $ruleTitle; Remove-Record 'fixture-rule' }
        Assert-Result 'trusted Diff accepts an authorized editable policy change' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $ruleHead) 0 'Trusted base run passed'
        $check = Get-DiffCheck
        $candidateCheck = @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'policy-candidates' })
        if ($check.Count -ne 1 -or -not ([string]$check[0].reason).Contains("$authorizations/fixture-rule.json (consumed)") -or $candidateCheck.Count -ne 1 -or $candidateCheck[0].status -ne 'pass') { $failures.Add("Diff summary does not report the weaken-policy consumption and candidate validation: $($check | ConvertTo-Json -Compress) $($candidateCheck | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS Diff summary reports the weaken-policy consumption and candidate validation' }
        Assert-Result 'an editable policy change without weaken-policy fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'rule-unauthorized' $authorizedBase $ruleTitle)) 1 "Uncovered policy-weakening needs a base authorization that this change deletes: $ruleFile"
        Assert-Result 'a formatting-only policy change needs no authorization' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'rule-format' $authorizedBase { Edit-Json $ruleFile { param($d) } })) 0 'no protected changes'
        Assert-Result 'a policy change beyond the authorized pointers fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'rule-extra-pointer' $authorizedBase { & $ruleTitle; Edit-Text $ruleFile { param($t) $t.Replace('"enforcement": "advisory"', '"enforcement": "blocking"') }; Remove-Record 'fixture-rule' })) 1 "changed pointers of $ruleFile differ from the authorization"
        Assert-Result 'an authorized added policy file passes' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'consume-new-rule' $authorizedBase { & $newRule; Remove-Record 'fixture-new-rule' })) 0 'obligation(s) covered'
        Assert-Result 'an unregistered policy file fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'unregistered-policy' $authorizedBase { [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_ifx/policy/fixture-extra.json'), "{}`n", $utf8) })) 1 'Unregistered policy or configuration file: docs/guards/V3_ifx/policy/fixture-extra.json'
        Assert-Result 'a .gitattributes change without weaken-policy fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'gitattributes' $authorizedBase $gitattributesEdit)) 1 'Uncovered policy-weakening needs a base authorization that this change deletes: .gitattributes'
        Assert-Result 'an authorized .gitattributes change passes' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'consume-gitattributes' $authorizedBase { & $gitattributesEdit; Remove-Record 'fixture-gitattributes' })) 0 'obligation(s) covered'
        Assert-Result 'a trust/meta change with only change-trusted-base fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'stage-tcb-only' $authorizedBase { & $stageEdit; Remove-Record 'fixture-stage-tcb' })) 1 'Uncovered policy-weakening needs a base authorization that this change deletes: docs/guards/V3_ifx/stages/diff/stage.json'
        Assert-Result 'a trust/meta change with both authorizations passes' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'stage-both' $authorizedBase { & $stageEdit; Remove-Record 'fixture-stage-tcb'; Remove-Record 'fixture-stage-weaken' })) 0 '2 obligation(s) covered'
        Assert-Result 'an unused weaken-policy authorization fails' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'unused-weaken' $authorizedBase { & $engineComment; Remove-Record 'fixture-consumption'; Remove-Record 'fixture-rule' })) 1 'has no semantic policy change in this pull request'

        Assert-Result 'head candidates of an authorized policy change pass' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase $ruleHead) 0 'Policy candidate validation passed'
        Assert-Result 'a policy change with stale profile views fails candidate validation' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase (New-PlannedHead 'rule-stale-views' $authorizedBase $staleRuleTitle)) 1 'the head profile views differ from what the base renderer produces'
        Assert-Result 'an invalid head profile fails candidate validation' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase (New-PlannedHead 'rule-invalid' $authorizedBase { Edit-Text $ruleFile { param($t) $t.Replace('"enforcement": "advisory"', '"enforcement": "sometimes"') } })) 1 'the base V3 runner rejects the head profile'
        Assert-Result 'a head history manifest that does not match head evidence fails' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase (New-PlannedHead 'history-tamper' $authorizedBase { Edit-Json 'docs/guards/V3_ifx/history/manifest.json' { param($d) $d.entries[0].sha256 = ('0' * 64) } })) 1 'the base historical integrity engine rejects the head manifest'
        Assert-Result 'a derived projection edited without its authority fails' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase (New-PlannedHead 'projection-tamper' $authorizedBase { Edit-Json 'docs/guards/V3_ifx/policy/g05/context-protocol-v1.json' { param($d) $d.owner = 'fixture' } })) 1 'head projections differ from the base generator output'
        Assert-Result 'a schema field without a monotonicity declaration fails' (Invoke-PolicyCandidates $authorizedWorktree $authorizedBase (New-PlannedHead 'schema-field' $authorizedBase { Edit-Json 'docs/guards/V3_ifx/contracts/rule.schema.json' { param($d) $d.properties['fixtureField'] = [ordered]@{ type = 'string' } } })) 1 'Schema field without a monotonicity declaration: docs/guards/V3_ifx/contracts/rule.schema.json#/properties/fixtureField'

        # ---- D18 domain authority coverage for an explicit head commit (D25)
        Assert-Result 'a domain authority waiver without weaken-policy fails the verifier' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase (New-PlannedHead 'waiver-unauthorized' $authorizedBase $waiverEdit)) 1 "Uncovered policy-weakening needs a base authorization that this change deletes: $catalog"
        Assert-Result 'the same waiver fails a Validate run for its explicit head' (Invoke-Runner $authorizedWorktree $authorizedBase 'Validate' @('-HeadRef', (Invoke-FixtureGit $clone @('rev-parse', 'HEAD'))[0], '-GateId', 'v3-architecture')) 1 'blocking findings are not covered by exactly one base weaken-policy authorization'
        $waiverHead = New-PlannedHead 'consume-waiver' $authorizedBase { & $waiverEdit; Remove-Record 'fixture-waiver' }
        Assert-Result 'an authorized domain authority waiver passes the verifier' (Invoke-ProtectedVerifier $authorizedWorktree $authorizedBase $waiverHead) 0 'obligation(s) covered'
        Assert-Result 'an authorized waiver passes Validate for its explicit head' (Invoke-Runner $authorizedWorktree $authorizedBase 'Validate' @('-HeadRef', $waiverHead, '-GateId', 'v3-architecture')) 0 'Trusted base run passed'
        $authorityCheck = @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-validate.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'domain-authority-candidates' })
        if ($authorityCheck.Count -ne 1 -or $authorityCheck[0].status -ne 'pass' -or -not ([string]$authorityCheck[0].reason).Contains("Blocking findings covered by base weaken-policy authorizations for head ${waiverHead}: $catalog")) { $failures.Add("Validate summary does not report the recomputed coverage: $($authorityCheck | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS Validate summary reports the coverage recomputed for the explicit head' }
        Assert-Result 'an authorized waiver still fails closed without an explicit head' (Invoke-Runner $authorizedWorktree $authorizedBase 'Validate' @('-GateId', 'v3-architecture')) 1 'without an explicit head and a covering base weaken-policy authorization'
        Edit-Json $catalog { param($d) $d.waivers += [ordered]@{ id = 'fixture-checkout-only' } }
        Assert-Result 'a checkout that differs from the explicit head fails' (Invoke-Runner $authorizedWorktree $authorizedBase 'Validate' @('-HeadRef', $waiverHead, '-GateId', 'v3-architecture')) 1 "The checked-out authorities differ from the explicit head commit ${waiverHead}: $catalog"
        [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', $waiverHead))

        if ($failures.Count -gt 0) { foreach ($failure in $failures) { Write-Host "FAIL $failure" }; exit 1 }
        Write-Host 'IFX trusted base protected change authorization tests passed.'
        return
    }

    # ---- §11.1: provenance and cleanliness of the base worktree
    [void](New-Head 'benign' $baseSha { Edit-Text 'README.md' { param($t) $t + "`nfixture`n" } })
    Assert-Result 'benign head passes from the trusted base' (Invoke-Runner $base $baseSha 'HistoricalIntegrity' @('-GateId', 'v3-historical-integrity')) 0 'Trusted base run passed'
    $summary = Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-historicalintegrity.json') -Raw | ConvertFrom-Json
    if ($summary.gate.type -ne 'judging' -or $summary.baseSha -ne $baseSha) { $failures.Add('Trusted base summary does not report the gate guarantee and base provenance.') } else { Write-Host 'PASS summary reports gate guarantee and provenance' }
    Assert-Result 'base SHA mismatch fails' (Invoke-Runner $base ('0' * 40) 'HistoricalIntegrity') 1 'The trusted base worktree is at'
    [IO.File]::WriteAllText((Join-Path $base 'untracked-fixture.txt'), 'dirty', $utf8)
    Assert-Result 'dirty base worktree fails' (Invoke-Runner $base $baseSha 'HistoricalIntegrity') 1 'The trusted base worktree is not clean'
    [IO.File]::Delete((Join-Path $base 'untracked-fixture.txt'))
    $inner = Join-Path $clone 'inner-base'
    [void](Invoke-FixtureGit $clone @('worktree', 'add', '-q', '--detach', $inner, $baseSha))
    Assert-Result 'base worktree inside the head checkout fails' (Invoke-GuardIsolatedPwsh (Join-Path $inner 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1') @('-HeadRoot', $clone, '-BaseSha', $baseSha, '-Mode', 'HistoricalIntegrity') -WorkingDirectory $clone) 1 'must not contain each other'
    [void](Invoke-FixtureGit $clone @('worktree', 'remove', '--force', $inner))

    # ---- §11.1 negative controls: head tampering cannot change a judging verdict
    [void](New-Head 'tamper-dispatcher' $baseSha {
        & $breakEvidence
        [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1'), "exit 0`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_ifx/trusted-base/TrustedBase.psm1'), "function Invoke-GuardIsolatedPwsh { [pscustomobject]@{ ExitCode = 0; Output = '' } }`n", $utf8)
        Edit-Json 'docs/guards/V3_ifx/shared/commands.json' { param($d) $d.commands = @($d.commands | Select-Object -First 1) }
    })
    $inPlace = Invoke-GuardIsolatedPwsh (Join-Path $clone 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1') @('-Mode', 'HistoricalIntegrity') -WorkingDirectory $clone
    if ($inPlace.ExitCode -ne 0) { $failures.Add('The dispatcher tamper fixture is not effective in place.') } else { Write-Host 'PASS dispatcher tamper passes when run from head' }
    Assert-Result 'dispatcher, module and commands.json tamper cannot hide a violation' (Invoke-Runner $base $baseSha 'HistoricalIntegrity') 1 'FAIL guardrails'
    [void](New-Head 'tamper-engine' $baseSha { & $breakEvidence; Edit-Text $historyEngine { param($t) $t.Replace('$hashMatches = (Hash-CanonicalText $full) -eq $entry.sha256', '$hashMatches = $true') } })
    Assert-Result 'engine tamper cannot hide a violation' (Invoke-Runner $base $baseSha 'HistoricalIntegrity') 1 'FAIL guardrails'
    [void](New-Head 'tamper-policy' $baseSha {
        & $breakEvidence
        $text = [IO.File]::ReadAllText((Join-Path $clone $evidence)).Replace("`r`n", "`n")
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($text))).ToLowerInvariant()
        Edit-Json 'docs/guards/V3_ifx/history/manifest.json' { param($d) @($d.entries | Where-Object { $_.path -eq $evidence })[0].sha256 = $hash }
    })
    $inPlace = Invoke-GuardIsolatedPwsh (Join-Path $clone 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1') @('-Mode', 'HistoricalIntegrity') -WorkingDirectory $clone
    if ($inPlace.ExitCode -ne 0) { $failures.Add('The policy tamper fixture is not effective in place.') } else { Write-Host 'PASS policy tamper passes when run from head' }
    Assert-Result 'head policy tamper cannot hide a violation' (Invoke-Runner $base $baseSha 'HistoricalIntegrity') 1 'FAIL guardrails'
    [void](New-Head 'msbuild-injection' $baseSha {
        [IO.File]::WriteAllText((Join-Path $clone 'Directory.Build.props'), "<Project><Target Name=`"InjectedFailure`" BeforeTargets=`"Restore;Build`"><Error Text=`"head injection`" /></Target></Project>`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $clone 'Directory.Packages.props'), "<Project><PropertyGroup><NuGetAudit>false</NuGetAudit></PropertyGroup></Project>`n", $utf8)
    })
    Assert-Result 'head MSBuild inheritance injection does not change Validate' (Invoke-Runner $base $baseSha 'Validate') 0 'Trusted base run passed'

    # ---- §12.6: domain authority candidates
    [void](New-Head 'authority-waiver' $baseSha { Edit-Json $catalog { param($d) $d.waivers += [ordered]@{ id = 'fixture-waiver' } } })
    Assert-Result 'head waiver fails closed before candidate projection' (Invoke-Runner $base $baseSha 'Validate') 1 'FAIL domain-authority-candidates'
    [void](New-Head 'authority-declaration' $baseSha { Edit-Json $catalog { param($d) $consumer = $d.consumers[0].Clone(); $consumer.id = 'fixture-consumer'; $d.consumers += $consumer } })
    $direct = Invoke-GuardIsolatedPwsh (Join-Path $base 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1') @('-Mode', 'Validate', '-TargetRoot', $clone) -WorkingDirectory $clone
    if ($direct.ExitCode -eq 0) { $failures.Add('Base projections unexpectedly accepted a changed head catalog; the candidate projection control is not effective.') } else { Write-Host 'PASS stale base projection rejects the declaration change' }
    Assert-Result 'declaration change passes with a candidate projection' (Invoke-Runner $base $baseSha 'Validate') 0 'Trusted base run passed'
    $projection = @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-validate.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'candidate-projection' })
    if ($projection.Count -ne 1 -or $projection[0].status -ne 'pass' -or -not ([string]$projection[0].reason).Contains('docs/guards/V3_ifx/policy/g03/catalog.json')) { $failures.Add("Candidate projection was not regenerated from the head catalog: $($projection | ConvertTo-Json -Compress)") }
    else { Write-Host 'PASS candidate projection regenerated from the head catalog' }

    # ---- §11.5: trusted component candidates
    [void](New-Head 'tcb-none' $baseSha { Edit-Text 'README.md' { param($t) $t + "`nfixture`n" } })
    Assert-Result 'no trusted component change passes' (Invoke-Verifier $base $baseSha) 0 'no trusted component changes'
    [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', $baseSha))
    Assert-Result 'head equal to base passes' (Invoke-Verifier $base $baseSha) 0 'no trusted component changes'
    $engineComment = { Edit-Text $historyEngine { param($t) $t.Replace("`$ErrorActionPreference = 'Stop'", "# fixture: behaviour-equivalent change`n`$ErrorActionPreference = 'Stop'") } }
    [void](New-Head 'tcb-unauthorized' $baseSha $engineComment)
    Assert-Result 'engine change without authorization fails' (Invoke-Verifier $base $baseSha) 1 'require a base change-trusted-base authorization for: tcb.engine.historical-integrity'
    [void](New-Head 'tcb-manifest' $baseSha { Edit-Json 'docs/guards/V3_ifx/shared/trusted-components.json' { param($d) $d.components = @($d.components | Where-Object { $_.id -ne 'tcb.engine.historical-integrity' }) } })
    Assert-Result 'removing a component from the head manifest fails' (Invoke-Verifier $base $baseSha) 1 'tcb.manifest'
    [void](New-Head 'tcb-unregistered' $baseSha {
        [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/V3_ifx/scripts/Invoke-Unregistered.ps1'), "exit 0`n", $utf8)
        Edit-Text '.github/workflows/v3-ifx-guardrails.yml' { param($t) $t.Replace('./docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1', "./docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1`n          ./docs/guards/V3_ifx/scripts/Invoke-Unregistered.ps1") }
    })
    Assert-Result 'workflow activating an unregistered executable fails' (Invoke-Verifier $base $baseSha) 1 'no trusted component manifest registers: docs/guards/V3_ifx/scripts/Invoke-Unregistered.ps1'

    # Two-PR protocol: prepare the change, authorize it in base, then consume the authorization.
    function Test-AuthorizedChange([string] $Label, [scriptblock] $Change, [int] $Expected, [string] $ExpectText, [switch] $KeepAuthorization, [scriptblock] $AfterAuthorization) {
        $prepared = New-Head "prepare-$Label" $baseSha $Change
        $record = Join-Path $work "$Label.json"
        $helper = Invoke-GuardIsolatedPwsh (Join-Path $base 'docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1') @('-Id', $Label, '-BaseRevision', $baseSha, '-HeadRevision', $prepared, '-PlanPath', 'README.md', '-DecisionPaths', 'README.md', '-ParityContract', 'Fixture: verdicts unchanged on the fixed corpus.', '-Repository', $clone, '-OutputPath', $record) -WorkingDirectory $clone
        if ($helper.ExitCode -ne 0) { $failures.Add("$Label authorization helper failed: $($helper.Output)"); return }
        $authorizationPath = "docs/guards/V3_ifx/stages/diff/authorizations/$Label.json"
        $authorizedBase = New-Head "authorize-$Label" $baseSha { Copy-Item -LiteralPath $record -Destination ([IO.Directory]::CreateDirectory((Split-Path (Join-Path $clone $authorizationPath))).FullName) }
        $consuming = New-Head "change-$Label" $authorizedBase {
            & $Change
            if (-not $KeepAuthorization) { [IO.File]::Delete((Join-Path $clone $authorizationPath)) }
            if ($AfterAuthorization) { & $AfterAuthorization }
        }
        $worktree = New-BaseWorktree "b-$Label" $authorizedBase
        [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', $consuming))
        Assert-Result $Label (Invoke-Verifier $worktree $authorizedBase) $Expected $ExpectText
    }
    Test-AuthorizedChange 'authorized-equivalent-change' $engineComment 0 'authorized change of tcb.engine.historical-integrity'
    Test-AuthorizedChange 'authorization-not-consumed' $engineComment 1 'Head must delete the consumed authorization' -KeepAuthorization
    Test-AuthorizedChange 'head-differs-from-authorization' $engineComment 1 'differs from the authorization' -AfterAuthorization { Edit-Text $historyEngine { param($t) $t + "`n# unauthorized extra change`n" } }
    Test-AuthorizedChange 'engine-and-own-test-weakened' {
        Edit-Text $historyEngine { param($t) $t.Replace('$hashMatches = (Hash-CanonicalText $full) -eq $entry.sha256', '$hashMatches = $true') }
        [IO.File]::WriteAllText((Join-Path $clone $historyTest), "Write-Host 'weakened test'`n", $utf8)
    } 1 'Base-owned validation failed on the candidate: docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1'
    Test-AuthorizedChange 'engine-weakened-and-test-deleted' {
        Edit-Text $historyEngine { param($t) $t.Replace('$hashMatches = (Hash-CanonicalText $full) -eq $entry.sha256', '$hashMatches = $true') }
        [IO.File]::Delete((Join-Path $clone $historyTest))
    } 1 'Base-owned validation failed on the candidate: docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1'
    Test-AuthorizedChange 'summary-contract-changed' { Edit-Text 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1' { param($t) [Regex]::Replace($t, 'formatVersion = 1(\r?\n\s+mode = \$summaryMode)', 'formatVersion = 2$1').Replace("if (-not (Test-Json -LiteralPath `$summaryPath", "if (`$false -and -not (Test-Json -LiteralPath `$summaryPath") } } 1 'candidate summary schema valid: False'
    [void](New-Head 'tcb-lock-file' $baseSha { Edit-Text 'docs/guards/V3_ifx/build/locks/LayerGuard.packages.lock.json' { param($t) $t.Replace('"version": 1', '"version": 1 ') } })
    Assert-Result 'lock file change without authorization fails' (Invoke-Verifier $base $baseSha) 1 'require a base change-trusted-base authorization for: tcb.build.package-local'
    Test-AuthorizedChange 'verdict-changing-engine' { Edit-Text $historyEngine { param($t) $t.Replace("`$status = 'pass'; `$message = 'Frozen evidence is intact;", "`$status = 'fail'; `$message = 'Frozen evidence is intact;") } } 1 'Parity failed for HistoricalIntegrity'

    if ($failures.Count -gt 0) { foreach ($failure in $failures) { Write-Host "FAIL $failure" }; exit 1 }
    Write-Host 'IFX trusted base tests passed.'
}
finally {
    if (-not $KeepWorkDirectory -and [IO.Directory]::Exists($work)) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
