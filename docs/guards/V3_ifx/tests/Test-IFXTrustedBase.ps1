[CmdletBinding()]
param(
    [switch] $KeepWorkDirectory,
    # Runs only the trusted build isolation control, which builds LayerGuard (Plan 06 §11.2, P2.5).
    [switch] $ArchitectureOnly,
    # Runs only the end-to-end Diff and candidate verification controls for authorization consumption (D20).
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
        # §11.5/§12.1 with D20: the trusted Diff exempts only the authorization record that the base verifier confirms the
        # change consumes; every other protected deletion or rename, and any unverified consumption, stays blocked.
        $recordId = 'fixture-consumption'
        $recordPath = "docs/guards/V3_ifx/stages/diff/authorizations/$recordId.json"
        $changePlan = 'docs/guards/plans/20260917-fixture-change.plan.json'
        $decision = 'docs/guards/V3_ifx/decisions/history/20260917-v3-stage-d19-trusted-base-first-introduction.json'
        $engineComment = { Edit-Text $historyEngine { param($t) $t.Replace("`$ErrorActionPreference = 'Stop'", "# fixture: behaviour-equivalent change`n`$ErrorActionPreference = 'Stop'") } }

        function New-PlannedHead([string] $Name, [string] $From, [scriptblock] $Edits) {
            [void](Invoke-FixtureGit $clone @('checkout', '-q', '-f', '-B', $Name, $From))
            & $Edits
            [void](Invoke-FixtureGit $clone @('add', '-A'))
            [string[]] $planned = Invoke-FixtureGit $clone @('diff', '--cached', '--no-renames', '--name-only', $From)
            $planFile = Join-Path $clone $changePlan
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($planFile))
            $plan = [ordered]@{
                formatVersion = 1; id = '20260917-fixture-change'; title = "Fixture $Name"; goal = 'Exercise authorization consumption in the trusted Diff.'
                acceptanceCriteria = @('The trusted Diff verdict matches the expected authorization consumption outcome.')
                plannedPaths = @($planned | Sort-Object); areaIds = @('CI', 'GuardDocs', 'GuardPackage'); ruleIds = @(); validationCommands = @('ifx-package-test')
                decisionPaths = @($decision, 'docs/guards/V3_ifx/decisions/history/20260916-v3-stage-d10-protected-change-authorization.json')
            }
            [IO.File]::WriteAllText($planFile, ($plan | ConvertTo-Json -Depth 5), $utf8)
            [IO.File]::WriteAllText((Join-Path $clone 'docs/guards/plans/20260917-fixture-change.md'), "# Fixture $Name`n", $utf8)
            [void](Invoke-FixtureGit $clone @('add', '-A'))
            [void](Invoke-FixtureGit $clone @('commit', '-q', '-m', $Name))
            return (Invoke-FixtureGit $clone @('rev-parse', 'HEAD'))[0]
        }
        function Invoke-TrustedDiff([string] $Base, [string] $BaseSha, [string] $HeadSha, [hashtable] $Environment = @{}) {
            $script = Join-Path $Base 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1'
            return Invoke-GuardIsolatedPwsh $script @('-HeadRoot', $clone, '-BaseSha', $BaseSha, '-Mode', 'Diff', '-PlanPath', $changePlan, '-BaseRef', $BaseSha, '-HeadRef', $HeadSha, '-GateId', 'v3-pre-diff') -WorkingDirectory $clone -Environment $Environment
        }

        # Authorization PR: record generated from the prepared change, then committed to the base alone.
        $prepared = New-Head 'prepare-consumption' $baseSha $engineComment
        $recordFile = Join-Path $work "$recordId.json"
        $helper = Invoke-GuardIsolatedPwsh (Join-Path $base 'docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1') @('-Id', $recordId, '-BaseRevision', $baseSha, '-HeadRevision', $prepared, '-PlanPath', $changePlan, '-DecisionPaths', $decision, '-ParityContract', 'Fixture: verdicts unchanged on the fixed corpus.', '-Repository', $clone, '-OutputPath', $recordFile) -WorkingDirectory $clone
        if ($helper.ExitCode -ne 0) { throw "Authorization helper failed: $($helper.Output)" }
        $authorizedBase = New-Head 'authorize-consumption' $baseSha { Copy-GuardFiles $work $clone @() ; [void][IO.Directory]::CreateDirectory((Split-Path (Join-Path $clone $recordPath))); [IO.File]::Copy($recordFile, (Join-Path $clone $recordPath), $true) }
        $authorizedWorktree = New-BaseWorktree 'b-consumption' $authorizedBase

        $consume = New-PlannedHead 'consume' $authorizedBase { & $engineComment; [IO.File]::Delete((Join-Path $clone $recordPath)) }
        $result = Invoke-TrustedDiff $authorizedWorktree $authorizedBase $consume
        Assert-Result 'trusted Diff accepts the deletion of the exactly consumed authorization' $result 0 'Trusted base run passed'
        $check = @((Get-Content -LiteralPath (Join-Path $clone 'artifacts/guards/v3-ifx/trusted-base/summary-diff.json') -Raw | ConvertFrom-Json).checks | Where-Object { $_.id -eq 'consumed-authorization' })
        if ($check.Count -ne 1 -or $check[0].status -ne 'pass' -or -not ([string]$check[0].reason).Contains($recordPath)) { $failures.Add("Diff summary does not report the verified consumption: $($check | ConvertTo-Json -Compress)") }
        else { Write-Host 'PASS Diff summary reports the verified consumption' }
        Assert-Result 'candidate verification accepts the consuming change' (Invoke-GuardIsolatedPwsh (Join-Path $authorizedWorktree 'docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1') @('-TargetRoot', $clone, '-BaseSha', $authorizedBase, '-ParityModes', 'HistoricalIntegrity') -WorkingDirectory $clone) 0 'authorized change of tcb.engine.historical-integrity'
        Assert-Result 'an injected consumption variable does not reach the trusted Diff' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase (New-PlannedHead 'revoke-injected' $authorizedBase { [IO.File]::Delete((Join-Path $clone $recordPath)) }) @{ GUARD_CONSUMED_AUTHORIZATIONS = $recordPath }) 1 "Protected guard deletions: $recordPath"

        $revoke = New-PlannedHead 'revoke-only' $authorizedBase { [IO.File]::Delete((Join-Path $clone $recordPath)) }
        Assert-Result 'deleting an authorization without consuming it stays a protected deletion' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $revoke) 1 "Protected guard deletions: $recordPath"

        $mismatch = New-PlannedHead 'consume-mismatch' $authorizedBase { & $engineComment; Edit-Text $historyEngine { param($t) $t + "`n# unauthorized extra change`n" }; [IO.File]::Delete((Join-Path $clone $recordPath)) }
        Assert-Result 'a change that differs from the authorization keeps the deletion blocked' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $mismatch) 1 "Protected guard deletions: $recordPath"
        Assert-Result 'candidate verification rejects the mismatched change' (Invoke-GuardIsolatedPwsh (Join-Path $authorizedWorktree 'docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1') @('-TargetRoot', $clone, '-BaseSha', $authorizedBase, '-ParityModes', 'HistoricalIntegrity') -WorkingDirectory $clone) 1 'differs from the authorization'

        $extra = New-PlannedHead 'consume-plus-protected-deletion' $authorizedBase { & $engineComment; [IO.File]::Delete((Join-Path $clone $recordPath)); [IO.File]::Delete((Join-Path $clone 'docs/guards/V3_ifx/README.md')) }
        Assert-Result 'consumption does not exempt another protected deletion' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $extra) 1 'Protected guard deletions: docs/guards/V3_ifx/README.md'

        $renamed = New-PlannedHead 'consume-by-rename' $authorizedBase { & $engineComment; [void](Invoke-FixtureGit $clone @('mv', $recordPath, 'docs/guards/V3_ifx/stages/diff/authorizations/fixture-renamed.json')) }
        Assert-Result 'renaming the consumed authorization stays a protected deletion' (Invoke-TrustedDiff $authorizedWorktree $authorizedBase $renamed) 1 "Protected guard deletions: $recordPath"

        if ($failures.Count -gt 0) { foreach ($failure in $failures) { Write-Host "FAIL $failure" }; exit 1 }
        Write-Host 'IFX trusted base authorization consumption tests passed.'
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
