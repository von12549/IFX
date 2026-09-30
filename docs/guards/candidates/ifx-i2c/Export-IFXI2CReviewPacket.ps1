# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) step C4: review packet for the operator. It binds the C1 snapshot,
# the pull request spec with every authored file, the C3 rehearsal (steps, generated records, final state) and the
# remote steps that follow, and renders review.md. It changes nothing; the decision is recorded separately.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $SnapshotPath = 'artifacts/guards/p10-ifx-i2c/c1-remote-snapshot.json',
    [string] $RehearsalPath = 'artifacts/guards/p10-ifx-i2c/c3-rehearsal/rehearsal.json',
    [string] $OutputDirectory = 'artifacts/guards/p10-ifx-i2c/c4-review'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Full([string] $Relative) { [IO.Path]::GetFullPath((Join-Path $root $Relative)) }
function Bound([string] $Relative) { [ordered]@{ path = $Relative.Replace('\', '/'); sha256 = Get-IFXI2CFileSha256 (Full $Relative) } }
$snapshot = Get-Content -Raw -LiteralPath (Full $SnapshotPath) | ConvertFrom-Json -Depth 100
$rehearsal = Get-Content -Raw -LiteralPath (Full $RehearsalPath) | ConvertFrom-Json -Depth 100
$specRelative = 'docs/guards/candidates/ifx-i2c/pr-spec.json'
$spec = Get-Content -Raw -LiteralPath (Full $specRelative) | ConvertFrom-Json -Depth 20
Assert-IFXI2C ($snapshot.status -ceq 'pass') 'The C1 snapshot did not pass.'
Assert-IFXI2C ($rehearsal.status -ceq 'pass') 'The C3 rehearsal did not pass.'
Assert-IFXI2C ($rehearsal.specSha256 -ceq (Get-IFXI2CFileSha256 (Full $specRelative))) 'The spec changed after the rehearsal.'
Assert-IFXI2C ($rehearsal.parity -ceq 'full fixed corpus' -and [bool]$rehearsal.qualitySolution) 'The rehearsal is not the formal run (full parity and solution quality).'
$out = Full $OutputDirectory
Assert-IFXI2C (-not [IO.Directory]::Exists($out)) "The review packet already exists: $out"
[void][IO.Directory]::CreateDirectory($out)

$authoredFiles = [ordered]@{}
foreach ($entry in @($spec.sets)) {
    foreach ($suffix in '', 'a') {
        $dir = Join-Path $PSScriptRoot "pr/$($entry.id)$suffix"
        if (-not [IO.Directory]::Exists($dir)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -Recurse -File | Sort-Object FullName)) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
            $authoredFiles[$relative] = [ordered]@{ set = "$($entry.id)$suffix"; repositoryPath = [IO.Path]::GetRelativePath($dir, $file.FullName).Replace('\', '/'); sha256 = Get-IFXI2CFileSha256 $file.FullName }
        }
    }
}
$testDiff = (& git -C $root diff --no-index --no-color -- docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1 docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1 2>&1) -join "`n"
$policyDiff = (& git -C $root diff --no-index --no-color -- docs/guards/V3_ifx/shared/policy-config.json docs/guards/candidates/ifx-i2c/pr/P3/docs/guards/V3_ifx/shared/policy-config.json 2>&1) -join "`n"

$remote = @(
    [ordered]@{ step = 'C5'; action = 'P1: push codex/i2c-p1-drain-wait-fix, open PR to codex/guards-principles-plan'; then = 'merge (merge commit) after 13/13' },
    [ordered]@{ step = 'C6'; action = 'P2a: regenerate the two records on the then-current target head, push and open the authorization PR'; then = 'merge after 13/13; then P2: push and open the change PR consuming both records; merge after 13/13' },
    [ordered]@{ step = 'C7'; action = 'P3a: regenerate the two records, push and open the authorization PR'; then = 'merge after 13/13; then P3: push and open the change PR; merge after 13/13' },
    [ordered]@{ step = 'C8'; action = 'Set the default branch to codex/guards-principles-plan'; then = 'GET verify' },
    [ordered]@{ step = 'C9'; action = 'git push origin <target head>:refs/heads/main (fast-forward, no force)'; then = 'GET verify; irreversible' },
    [ordered]@{ step = 'C10'; action = 'Set the default branch back to main'; then = 'Invoke-IFXCiContract.ps1 -Remote; ruleset equals C1' },
    [ordered]@{ step = 'C12'; action = 'Push the development branch (after C11 records)'; then = 'GET verify' }
)
$packet = [ordered]@{
    formatVersion = 1
    kind = 'ifx-i2c-review-packet'
    planId = '20261001-v4-ifx-i2c-main-promotion'
    step = 'C4'
    createdAtUtc = [DateTime]::UtcNow.ToString('o')
    repositoryHead = (Invoke-IFXI2CGit $root @('rev-parse', 'HEAD'))[0].Trim()
    plan = Bound 'docs/guards/plans/20261001-v4-ifx-i2c-main-promotion.plan.json'
    snapshot = Bound $SnapshotPath
    rehearsal = Bound $RehearsalPath
    spec = Bound $specRelative
    rulesetCanonicalSha256 = [string]$snapshot.ruleset.canonicalSha256
    target = [string]$snapshot.heads.'codex/guards-principles-plan'
    mainBeforePromotion = [string]$snapshot.heads.main
    sourceCommit = [string]$spec.sourceCommit
    pullRequests = @($spec.sets | ForEach-Object { [ordered]@{ id = $_.id; branch = $_.branch; plan = $_.plan; copy = @($_.copy); authored = @($_.authored); authorizations = @($_.authorizations | ForEach-Object { [ordered]@{ id = $_.id; operation = $_.operation } }) } })
    authoredFiles = $authoredFiles
    rehearsalSteps = @($rehearsal.steps | ForEach-Object { [ordered]@{ id = $_.id; expectedExit = $_.expectedExit; exit = $_.exit; asExpected = $_.asExpected } })
    records = @($rehearsal.records.PSObject.Properties | ForEach-Object { [ordered]@{ path = $_.Name; sha256 = $_.Value.sha256; operation = $_.Value.record.operation; changedPaths = @($_.Value.record.changedPaths); components = @(if ($_.Value.record.PSObject.Properties['components']) { $_.Value.record.components }) } })
    finalState = $rehearsal.finalState
    notRunLocally = @($rehearsal.notRunLocally)
    remoteSteps = $remote
    questions = @(
        'Accept the three pull requests (P1, P2 with P2a, P3 with P3a), their V3 plans and the admission decision as prepared?',
        'Accept the rehearsal as the local proof, with the listed contexts left to CI?',
        'After acceptance, C5 (push and open P1) needs its own authorization.'
    )
}
Write-IFXI2CJson (Join-Path $out 'review-packet.json') $packet

$md = [Text.StringBuilder]::new()
function L([string] $Text = '') { [void]$md.AppendLine($Text) }
L '# IFX I2-C review packet (C4)'
L
L "Plan ``20261001-v4-ifx-i2c-main-promotion``. Repository head ``$($packet.repositoryHead)``."
L
L '## Remote state (C1, GET only)'
L
L "- ``main`` ``$($packet.mainBeforePromotion)``; target ``codex/guards-principles-plan`` ``$($packet.target)`` (PR #107 merge, 13/13 on 2026-09-21); linear, $($snapshot.linear.counts.mainToTarget) commits apart."
L "- Ruleset 23459908 canonical SHA-256 ``$($packet.rulesetCanonicalSha256)``; no bypass; 13 contexts, strict; no open pull requests; default branch ``main``."
L
L '## Pull requests'
L
L '| PR | Branch | Content | Authorization |'
L '| --- | --- | --- | --- |'
foreach ($entry in @($spec.sets)) {
    $content = @(@($entry.copy) + @($entry.authored) | ForEach-Object { "``$_``" }) -join '<br>'
    $auth = if (@($entry.authorizations).Count -gt 0) { "$($entry.id)a first: " + (@($entry.authorizations | ForEach-Object { "``$($_.id)`` ($($_.operation))" }) -join ', ') } else { 'none (no protected change)' }
    L "| $($entry.id) | ``$($entry.branch)`` | $content | $auth |"
}
L
L "Copied paths are byte-identical to ``$($spec.sourceCommit.Substring(0, 8))`` on the development branch; authored files are under ``docs/guards/candidates/ifx-i2c/pr/``."
L
L '### P3: the allowlist change'
L
L '```diff'
L $testDiff.Trim()
L '```'
L
L '### P3: decision registration'
L
L '```diff'
L $policyDiff.Trim()
L '```'
L
L '## Rehearsal (C3)'
L
L "Status **$($rehearsal.status)**; parity $($rehearsal.parity); solution quality run: $($rehearsal.qualitySolution). Every verdict came from the simulated base's own trusted runner, verifier and generator."
L
L '| Step | Expected exit | Exit | As expected |'
L '| --- | --- | --- | --- |'
foreach ($step in @($rehearsal.steps)) { L "| ``$($step.id)`` | $($step.expectedExit) | $($step.exit) | $($step.asExpected) |" }
L
L '### Generated records (rehearsal; regenerated on the real base in C6/C7)'
L
foreach ($record in @($packet.records)) { L "- ``$($record.path)`` ($($record.operation)): $(@($record.changedPaths) -join ', ')" }
L
L '### Final state of the simulated target'
L
L "- ``docs/guards``: $(@($rehearsal.finalState.docsGuardsTopLevel) -join ', ')"
L "- ``docs/guards/v4-adoption``: $(@($rehearsal.finalState.v4AdoptionFiles) -join ', ')"
L "- remaining authorization records: $(@($rehearsal.finalState.remainingAuthorizationRecords).Count); blob mismatches: $(@($rehearsal.finalState.finalBlobMismatches).Count)"
L
L "Not run locally (CI runs them on every pull request): $(@($rehearsal.notRunLocally) -join ', ')."
L
L '## Remote steps after acceptance (each separately authorized)'
L
L '| Step | Action | Then |'
L '| --- | --- | --- |'
foreach ($r in $remote) { L "| $($r.step) | $($r.action) | $($r.then) |" }
L
L '## Questions'
L
foreach ($q in $packet.questions) { L "- $q" }
[IO.File]::WriteAllText((Join-Path $out 'review.md'), $md.ToString(), [Text.UTF8Encoding]::new($false))
Write-Output "C4 review packet: $(Join-Path $out 'review-packet.json') $((Get-IFXI2CFileSha256 (Join-Path $out 'review-packet.json')).Substring(0, 12))"
