# IFX I2-D (Plan 20261001-v4-ifx-i2d-publish-trusted-inputs) step D1: GET-only snapshot of the remote state that the
# Plan's section 2 states. Every GitHub read uses the GET method (candidates/ifx-i2c/IFXI2C.Common.psm1); the only Git
# network operation is a fetch. The ruleset must equal the I2-C snapshot; main must equal codex/guards-principles-plan
# and hold only the v4-adoption README.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $OutputPath = 'artifacts/guards/p10-ifx-i2d/d1-remote-snapshot.json',
    [string] $ExpectedMain = '7b9b53dcc102fd8513927681641493101b4599ca',
    [string] $ExpectedRulesetSha256 = '857a51aaf9590758aa37ab0daf234695ba6e3a434644e598026d741b2c7d6f4a'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '../ifx-i2c/IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$repo = Get-IFXI2CRepositoryName
$failures = [Collections.Generic.List[string]]::new()
function Check([bool] $Condition, [string] $Message) { if (-not $Condition) { $failures.Add($Message) } }
[void](Invoke-IFXI2CGit $root @('fetch', '--quiet', '--prune', 'origin'))
$heads = [ordered]@{}
foreach ($branch in 'main', 'codex/guards-principles-plan', 'codex/v4-development-base') { $heads[$branch] = (Invoke-IFXI2CGit $root @('rev-parse', "refs/remotes/origin/$branch"))[0].Trim() }
Check ($heads['main'] -ceq $ExpectedMain) "main moved: $($heads['main'])"
Check ($heads['codex/guards-principles-plan'] -ceq $ExpectedMain) 'codex/guards-principles-plan differs from main.'
[void](Invoke-IFXI2CGit $root @('merge-base', '--is-ancestor', $heads['main'], $heads['codex/v4-development-base']) -AllowFailure)
$mainInDevelopment = $LASTEXITCODE -eq 0
Check $mainInDevelopment 'main is not an ancestor of the development branch.'
$adoptionLines = Invoke-IFXI2CGit $root @('ls-tree', '-r', '--name-only', "$($heads['main']):docs/guards/v4-adoption")
$adoption = @(foreach ($l in $adoptionLines) { ([string]$l).Trim() })
Check (($adoption -join ',') -ceq 'README.md') "main's v4-adoption is not only the README: $($adoption -join ', ')"
$repository = Invoke-IFXI2CGitHubGet "repos/$repo" | ConvertFrom-Json -AsHashtable -Depth 20
Check ($repository['default_branch'] -ceq 'main') "Default branch is $($repository['default_branch'])."
$ruleset = Get-IFXI2CRulesetIdentity
Check ($ruleset.canonicalSha256 -ceq $ExpectedRulesetSha256) "Ruleset differs from the I2-C snapshot: $($ruleset.canonicalSha256)"
$openPulls = @(Invoke-IFXI2CGitHubGet "repos/$repo/pulls?state=open&per_page=100" | ConvertFrom-Json -Depth 20)
Check ($openPulls.Count -eq 0) "There are $($openPulls.Count) open pull requests."
$snapshot = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2d-remote-snapshot'; planId = '20261001-v4-ifx-i2d-publish-trusted-inputs'; step = 'D1'
    capturedAtUtc = [DateTime]::UtcNow.ToString('o'); method = 'GET-only GitHub API reads and one git fetch'
    heads = $heads; mainAncestorOfDevelopment = $mainInDevelopment; mainV4Adoption = $adoption; defaultBranch = $repository['default_branch']
    ruleset = [ordered]@{ id = Get-IFXI2CRulesetId; canonicalSha256 = $ruleset.canonicalSha256; equalsI2C = ($ruleset.canonicalSha256 -ceq $ExpectedRulesetSha256) }
    openPullRequests = $openPulls.Count; failures = @($failures); status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
}
$out = [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
Write-IFXI2CJson $out $snapshot
if ($failures.Count -gt 0) { Write-Error ("D1 snapshot differs from the Plan:`n  " + ($failures -join "`n  ")); exit 1 }
Write-Output "D1 remote snapshot PASS: main $($heads['main'].Substring(0, 8)), ruleset equal to I2-C, no open pull requests -> $out"
