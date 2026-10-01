# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) steps C6/C7, first half: on the real target head, prepare the
# change head of a set (without its records), generate the set's records with the target's own
# New-IFXTrustedBaseAuthorization.ps1, require them to equal the C3 rehearsal records (records bind blobs only, so a
# target that did not touch the set's paths gives identical bytes), build the authorization head and preflight it with
# the target's trusted runner: the trusted Diff, the trusted component candidate check and Validate. Nothing is pushed.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^P[0-9]$')][string] $Set,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $Target,
    [string] $Clone = 'D:/IFX-Root/guard-runtime/i2c/pr-work',
    [string] $RepositoryRoot = '.',
    [string] $RehearsalRecords = 'artifacts/guards/p10-ifx-i2c/c3-rehearsal/records',
    [Parameter(Mandatory)][string] $OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
Import-Module (Join-Path $root 'docs/guards/V3_ifx/trusted-base/TrustedBase.psm1') -Force
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pr-spec.json') | ConvertFrom-Json -Depth 20
$entry = @($spec.sets | Where-Object id -CEQ $Set)[0]
Assert-IFXI2C (@($entry.authorizations).Count -gt 0) "Set $Set has no authorizations."
$clonePath = [IO.Path]::GetFullPath($Clone)
$work = Join-Path (Split-Path -Parent $clonePath) "auth-$($Set.ToLowerInvariant())-$([Guid]::NewGuid().ToString('N').Substring(0, 6))"
$records = Join-Path $work 'records'
[void][IO.Directory]::CreateDirectory($records)
$tree = Join-Path $work 'base'
$changePlan = [string]$entry.plan
$authorizationPlan = $changePlan.Replace('.plan.json', '-authorization.plan.json')
function CloneGit([string[]] $Arguments) { return Invoke-IFXI2CGit $clonePath $Arguments }
function Build([string] $Kind, [string] $RecordsDirectory) {
    $arguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'New-IFXI2CPullRequestHeads.ps1'), '-Clone', $clonePath, '-Set', $Set, '-BaseCommit', $Target, '-Kind', $Kind)
    if ($Kind -eq 'authorization') { $arguments += @('-RecordsDirectory', $RecordsDirectory) } else { $arguments += @('-Branch', "prepared/$($entry.branch)") }
    $text = (& pwsh @arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Building the $Kind head failed: $text" }
    return ($text.Split("`n") | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json -Depth 20
}
$checks = [Collections.Generic.List[object]]::new()
function Check([string] $Id, [object] $Run, [int] $Expected, [string] $Text) {
    $ok = $Run.ExitCode -eq $Expected -and $Run.Output.Contains($Text, [StringComparison]::Ordinal)
    $checks.Add([ordered]@{ id = $Id; exit = $Run.ExitCode; expectedExit = $Expected; asExpected = $ok; evidence = @($Run.Output -split "`n" | Where-Object { $_ -match 'passed|failed|FAIL|Uncovered|trusted component' } | ForEach-Object { $_.Trim().Replace($work, '<work>') } | Select-Object -Unique -First 8) })
    Write-Host ("[{0}] {1}: exit {2}" -f $(if ($ok) { 'OK' } else { 'UNEXPECTED' }), $Id, $Run.ExitCode)
}
try {
    # the clone gets the target from the repository, which fetched origin
    [void](Invoke-IFXI2CGit $root @('cat-file', '-e', "$Target^{commit}"))
    [void](CloneGit @('fetch', '-q', $root, '+refs/remotes/origin/*:refs/remotes/upstream/*'))
    [void](CloneGit @('cat-file', '-e', "$Target^{commit}"))
    [void](CloneGit @('worktree', 'add', '-q', '--detach', $tree, $Target))
    $prepared = Build 'change' ''
    foreach ($authorization in @($entry.authorizations)) {
        $arguments = @('-Id', $authorization.id, '-Operation', $authorization.operation, '-BaseRevision', $Target, '-HeadRevision', $prepared.head, '-PlanPath', $changePlan, '-DecisionPaths', (@($authorization.decisionPaths) -join ','), '-Repository', $clonePath, '-OutputPath', (Join-Path $records "$($authorization.id).json"))
        if ($authorization.operation -ceq 'change-trusted-base') { $arguments += @('-ParityContract', [string]$authorization.parityContract) }
        $run = Invoke-GuardIsolatedPwsh (Join-Path $tree 'docs/guards/V3_ifx/trusted-base/New-IFXTrustedBaseAuthorization.ps1') $arguments -WorkingDirectory $clonePath
        if ($run.ExitCode -ne 0) { throw "Generator failed for $($authorization.id): $($run.Output)" }
    }
    $comparison = @(foreach ($authorization in @($entry.authorizations)) {
            $new = [IO.File]::ReadAllText((Join-Path $records "$($authorization.id).json")).Replace("`r`n", "`n")
            $old = [IO.File]::ReadAllText((Join-Path (Join-Path $root $RehearsalRecords) "$($authorization.id).json")).Replace("`r`n", "`n")
            [ordered]@{ id = $authorization.id; equalToRehearsal = ($new -ceq $old); sha256 = Get-IFXI2CStringSha256 $new }
        })
    foreach ($item in $comparison) { Assert-IFXI2C $item.equalToRehearsal "Record $($item.id) differs from the C3 rehearsal record; stop and review." }
    $authorizationHead = Build 'authorization' $records
    [void](CloneGit @('checkout', '-q', '-f', $authorizationHead.head))
    Check 'authorization-diff' (Invoke-GuardIsolatedPwsh (Join-Path $tree 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1') @('-HeadRoot', $clonePath, '-BaseSha', $Target, '-Mode', 'Diff', '-PlanPath', $authorizationPlan, '-BaseRef', $Target, '-HeadRef', $authorizationHead.head, '-GateId', 'v3-pre-diff') -WorkingDirectory $clonePath) 0 'Trusted base run passed'
    Check 'authorization-candidates' (Invoke-GuardIsolatedPwsh (Join-Path $tree 'docs/guards/V3_ifx/trusted-base/Test-IFXTrustedBaseCandidate.ps1') @('-TargetRoot', $clonePath, '-BaseSha', $Target, '-HeadRevision', $authorizationHead.head) -WorkingDirectory $clonePath) 0 'no trusted component changes'
    [void](CloneGit @('checkout', '-q', '-f', $authorizationHead.head))
    Check 'authorization-validate' (Invoke-GuardIsolatedPwsh (Join-Path $tree 'docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1') @('-HeadRoot', $clonePath, '-BaseSha', $Target, '-Mode', 'Validate', '-HeadRef', $authorizationHead.head, '-GateId', 'v3-architecture') -WorkingDirectory $clonePath) 0 'Trusted base run passed'
    $pass = @($checks | Where-Object { -not $_.asExpected }).Count -eq 0
    $result = [ordered]@{
        formatVersion = 1; kind = 'ifx-i2c-authorization-head'; planId = '20261001-v4-ifx-i2c-main-promotion'; set = $Set
        createdAtUtc = [DateTime]::UtcNow.ToString('o'); target = $Target
        preparedChangeHead = $prepared.head; records = $comparison
        authorizationHead = $authorizationHead; checks = @($checks); status = if ($pass) { 'pass' } else { 'fail' }
    }
    Write-IFXI2CJson ([IO.Path]::GetFullPath((Join-Path $root $OutputPath))) $result
    Write-Output "$Set authorization head $($result.status): $($authorizationHead.branch) $($authorizationHead.head)"
    if (-not $pass) { exit 1 }
}
finally {
    [void](& git -C $clonePath worktree remove --force $tree 2>&1)
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
