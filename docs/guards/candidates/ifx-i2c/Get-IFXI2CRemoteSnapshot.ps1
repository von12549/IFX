# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) step C1: GET-only snapshot of the remote state that the Plan's
# section 2 states. Every GitHub read uses the GET method; the only Git network operation is a fetch. The snapshot
# fails when a stated fact does not hold (stop condition), and it is the reference that C10 compares the ruleset with.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $OutputPath = 'artifacts/guards/p10-ifx-i2c/c1-remote-snapshot.json',
    [string] $ExpectedMain = 'ecb03726a6c67208d25e7988695c53f6326d77c0',
    [string] $ExpectedTarget = '57647c9ae75c25666d825477c7a1ea11073468c5',
    [string] $ExpectedPr107Head = '732f8d65b34f4e746727b42752d9cc17453408d6'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$repo = Get-IFXI2CRepositoryName
$failures = [Collections.Generic.List[string]]::new()
function Check([bool] $Condition, [string] $Message) { if (-not $Condition) { $failures.Add($Message) } }

[void](Invoke-IFXI2CGit $root @('fetch', '--quiet', '--prune', 'origin'))
$heads = [ordered]@{}
foreach ($branch in 'main', 'codex/guards-principles-plan', 'codex/v4-development-base') {
    $heads[$branch] = (Invoke-IFXI2CGit $root @('rev-parse', "refs/remotes/origin/$branch"))[0].Trim()
}
$localHead = (Invoke-IFXI2CGit $root @('rev-parse', 'HEAD'))[0].Trim()
Check ($heads['main'] -ceq $ExpectedMain) "main moved: $($heads['main'])"
Check ($heads['codex/guards-principles-plan'] -ceq $ExpectedTarget) "codex/guards-principles-plan moved: $($heads['codex/guards-principles-plan'])"
[void](Invoke-IFXI2CGit $root @('merge-base', '--is-ancestor', $heads['main'], $heads['codex/guards-principles-plan']) -AllowFailure)
$mainInTarget = $LASTEXITCODE -eq 0
[void](Invoke-IFXI2CGit $root @('merge-base', '--is-ancestor', $heads['codex/guards-principles-plan'], $heads['codex/v4-development-base']) -AllowFailure)
$targetInDevelopment = $LASTEXITCODE -eq 0
Check $mainInTarget 'main is not an ancestor of codex/guards-principles-plan.'
Check $targetInDevelopment 'codex/guards-principles-plan is not an ancestor of the development branch.'
$counts = [ordered]@{
    mainToTarget = [int](Invoke-IFXI2CGit $root @('rev-list', '--count', "$($heads['main'])..$($heads['codex/guards-principles-plan'])"))[0]
    targetToDevelopment = [int](Invoke-IFXI2CGit $root @('rev-list', '--count', "$($heads['codex/guards-principles-plan'])..$($heads['codex/v4-development-base'])"))[0]
}
$targetParents = @(((Invoke-IFXI2CGit $root @('show', '-s', '--format=%P', $heads['codex/guards-principles-plan']))[0]).Trim().Split(' '))
Check ($targetParents.Count -eq 2 -and $targetParents[1] -ceq $ExpectedPr107Head) 'codex/guards-principles-plan is not the PR #107 merge of 732f8d65.'

$repository = Invoke-IFXI2CGitHubGet "repos/$repo" | ConvertFrom-Json -AsHashtable -Depth 20
$settings = [ordered]@{}
foreach ($key in 'default_branch', 'visibility', 'allow_merge_commit', 'allow_squash_merge', 'allow_rebase_merge', 'delete_branch_on_merge') { $settings[$key] = $repository[$key] }
Check ($settings.default_branch -ceq 'main') "Default branch is $($settings.default_branch), not main."
Check ([bool]$settings.allow_merge_commit) 'Merge commits are not allowed (RC5).'

$ruleset = Get-IFXI2CRulesetIdentity
$config = $ruleset.configuration
Check ($config.enforcement -ceq 'active') 'Ruleset is not active.'
Check (@($config.bypass_actors).Count -eq 0) 'Ruleset has bypass actors.'
$include = @($config.conditions.ref_name.include)
Check ((@($include | Sort-Object) -join ',') -ceq '~DEFAULT_BRANCH,refs/heads/codex/guards-principles-plan') "Ruleset targets differ: $($include -join ',')"
$types = @($config.rules | ForEach-Object { [string]$_.type } | Sort-Object)
Check (($types -join ',') -ceq 'deletion,non_fast_forward,pull_request,required_status_checks') "Ruleset rule types differ: $($types -join ',')"
$checks = @($config.rules | Where-Object { $_.type -ceq 'required_status_checks' })[0].parameters
Check ([bool]$checks.strict_required_status_checks_policy) 'Required checks are not strict.'
$contexts = @($checks.required_status_checks | ForEach-Object { [string]$_.context } | Sort-Object)
Check (($contexts -join ',') -ceq ((Get-IFXI2CRequiredContexts | Sort-Object) -join ',')) "Required contexts differ: $($contexts -join ',')"

$openPulls = @(Invoke-IFXI2CGitHubGet "repos/$repo/pulls?state=open&per_page=100" | ConvertFrom-Json -Depth 20)
Check ($openPulls.Count -eq 0) "There are $($openPulls.Count) open pull requests."
$rollup = (& gh pr view 107 --repo $repo --json headRefOid,mergeCommit,statusCheckRollup 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "gh pr view 107 failed: $rollup" }
$pr107 = $rollup | ConvertFrom-Json -Depth 20
$pr107Checks = @($pr107.statusCheckRollup | ForEach-Object { [ordered]@{ name = [string]$_.name; conclusion = [string]$_.conclusion; completedAt = $(if ($_.completedAt -is [datetime]) { $_.completedAt.ToUniversalTime().ToString('o') } else { [string]$_.completedAt }) } } | Sort-Object { $_.name })
Check ($pr107.headRefOid -ceq $ExpectedPr107Head) 'PR #107 head differs.'
Check ([string]$pr107.mergeCommit.oid -ceq $ExpectedTarget) 'PR #107 merge commit is not codex/guards-principles-plan.'
Check ((@($pr107Checks | Where-Object { $_.conclusion -ceq 'SUCCESS' } | ForEach-Object name | Sort-Object) -join ',') -ceq ((Get-IFXI2CRequiredContexts | Sort-Object) -join ',')) 'PR #107 did not pass exactly the 13 required contexts.'
$lastRun = @($pr107Checks | ForEach-Object completedAt | Sort-Object)[-1]
$targetRuns = (Invoke-IFXI2CGitHubGet "repos/$repo/actions/runs?branch=codex/guards-principles-plan&per_page=5" | ConvertFrom-Json -Depth 20).total_count

$snapshot = [ordered]@{
    formatVersion = 1
    kind = 'ifx-i2c-remote-snapshot'
    planId = '20261001-v4-ifx-i2c-main-promotion'
    step = 'C1'
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    method = 'GET-only GitHub API reads and one git fetch'
    localHead = $localHead
    heads = $heads
    linear = [ordered]@{ mainAncestorOfTarget = $mainInTarget; targetAncestorOfDevelopment = $targetInDevelopment; counts = $counts }
    target = [ordered]@{ branch = 'codex/guards-principles-plan'; commit = $heads['codex/guards-principles-plan']; parents = $targetParents; pullRequest = 107; pullRequestHead = [string]$pr107.headRefOid; lastRequiredCheckCompletedAt = $lastRun; checks = $pr107Checks; branchWorkflowRunCount = [int]$targetRuns }
    repositorySettings = $settings
    ruleset = [ordered]@{ id = Get-IFXI2CRulesetId; canonicalSha256 = $ruleset.canonicalSha256; updatedAt = $ruleset.updatedAt; configuration = $config }
    openPullRequests = $openPulls.Count
    rollbackAnchor = [ordered]@{ mainBeforePromotion = $heads['main'] }
    failures = @($failures)
    status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
}
$out = [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
Write-IFXI2CJson $out $snapshot
if ($failures.Count -gt 0) { Write-Error ("C1 snapshot differs from the Plan:`n  " + ($failures -join "`n  ")); exit 1 }
Write-Output "C1 remote snapshot PASS: ruleset $($ruleset.canonicalSha256.Substring(0, 12)), target $($heads['codex/guards-principles-plan'].Substring(0, 8)), main $($heads['main'].Substring(0, 8)) -> $out"
