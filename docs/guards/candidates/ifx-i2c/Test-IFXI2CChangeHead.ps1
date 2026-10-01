# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) steps C6/C7, second half: on the real target head that already
# holds a set's records, build the change head that consumes (deletes) them and preflight it with the target's own
# trusted runner: the trusted Diff, the trusted component candidate check with full parity, the policy candidate
# validation, Validate and the G03 specialized gate. Nothing is pushed.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^P[0-9]$')][string] $Set,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $Target,
    [string] $Clone = 'D:/IFX-Root/guard-runtime/i2c/pr-work',
    [string] $RepositoryRoot = '.',
    [Parameter(Mandatory)][string] $OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
Import-Module (Join-Path $root 'docs/guards/V3_ifx/trusted-base/TrustedBase.psm1') -Force
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pr-spec.json') | ConvertFrom-Json -Depth 20
$entry = @($spec.sets | Where-Object id -CEQ $Set)[0]
$clonePath = [IO.Path]::GetFullPath($Clone)
$work = Join-Path (Split-Path -Parent $clonePath) "change-$($Set.ToLowerInvariant())-$([Guid]::NewGuid().ToString('N').Substring(0, 6))"
$tree = Join-Path $work 'base'
function CloneGit([string[]] $Arguments) { return Invoke-IFXI2CGit $clonePath $Arguments }
$checks = [Collections.Generic.List[object]]::new()
function Check([string] $Id, [object] $Run, [string] $Text) {
    $ok = $Run.ExitCode -eq 0 -and $Run.Output.Contains($Text, [StringComparison]::Ordinal)
    $checks.Add([ordered]@{ id = $Id; exit = $Run.ExitCode; asExpected = $ok; evidence = @($Run.Output -split "`n" | Where-Object { $_ -match 'passed|failed|FAIL|Uncovered|authorized change|consumed' } | ForEach-Object { $_.Trim().Replace($work, '<work>') } | Select-Object -Unique -First 10) })
    Write-Host ("[{0}] {1}: exit {2}" -f $(if ($ok) { 'OK' } else { 'UNEXPECTED' }), $Id, $Run.ExitCode)
}
function Trusted([string] $Script, [string[]] $Arguments) { Invoke-GuardIsolatedPwsh (Join-Path $tree "docs/guards/V3_ifx/trusted-base/$Script") $Arguments -WorkingDirectory $clonePath }
try {
    [void][IO.Directory]::CreateDirectory($work)
    [void](CloneGit @('fetch', '-q', $root, '+refs/remotes/origin/*:refs/remotes/upstream/*'))
    foreach ($authorization in @($entry.authorizations)) { [void](CloneGit @('cat-file', '-e', "${Target}:$($spec.authorizationDirectory)/$($authorization.id).json")) }
    [void](CloneGit @('worktree', 'add', '-q', '--detach', $tree, $Target))
    $text = (& pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'New-IFXI2CPullRequestHeads.ps1') -Clone $clonePath -Set $Set -BaseCommit $Target -Kind change -ConsumeRecords 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Building the change head failed: $text" }
    $built = ($text.Split("`n") | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json -Depth 20
    $head = [string]$built.head
    $plan = [string]$entry.plan
    [void](CloneGit @('checkout', '-q', '-f', $head)); [void](CloneGit @('clean', '-q', '-fdx'))
    Check 'change-diff' (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clonePath, '-BaseSha', $Target, '-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', $Target, '-HeadRef', $head, '-GateId', 'v3-pre-diff')) 'Trusted base run passed'
    Check 'change-candidates' (Trusted 'Test-IFXTrustedBaseCandidate.ps1' @('-TargetRoot', $clonePath, '-BaseSha', $Target, '-HeadRevision', $head)) 'authorized change of'
    Check 'change-policy-candidates' (Trusted 'Test-IFXPolicyCandidates.ps1' @('-TargetRoot', $clonePath, '-BaseSha', $Target, '-HeadRevision', $head, '-ReportPath', (Join-Path $work 'policy-candidates.json'))) 'Policy candidate validation passed'
    [void](CloneGit @('checkout', '-q', '-f', $head)); [void](CloneGit @('clean', '-q', '-fdx'))
    Check 'change-validate' (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clonePath, '-BaseSha', $Target, '-Mode', 'Validate', '-HeadRef', $head, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    [void](CloneGit @('checkout', '-q', '-f', $head)); [void](CloneGit @('clean', '-q', '-fdx'))
    Check 'change-g03' (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clonePath, '-BaseSha', $Target, '-Mode', 'Specialized', '-SpecializedGate', 'G03', '-HeadRef', $head, '-GateId', 'v3-specialized-g03')) 'Trusted base run passed'
    $pass = @($checks | Where-Object { -not $_.asExpected }).Count -eq 0
    $result = [ordered]@{ formatVersion = 1; kind = 'ifx-i2c-change-head'; planId = '20261001-v4-ifx-i2c-main-promotion'; set = $Set; createdAtUtc = [DateTime]::UtcNow.ToString('o'); target = $Target; changeHead = $built; checks = @($checks); status = if ($pass) { 'pass' } else { 'fail' } }
    Write-IFXI2CJson ([IO.Path]::GetFullPath((Join-Path $root $OutputPath))) $result
    Write-Output "$Set change head $($result.status): $($built.branch) $head"
    if (-not $pass) { exit 1 }
}
finally {
    [void](& git -C $clonePath worktree remove --force $tree 2>&1)
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
