# IFX I2-D (Plan 20261001-v4-ifx-i2d-publish-trusted-inputs) step D5: review packet for the operator. It binds the D1
# snapshot, the D2 bundle copy, the publication spec with its authored files, and the D4 rehearsal, lists what main will
# receive, and renders review.md. It changes nothing; the decision is recorded separately.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $SnapshotPath = 'artifacts/guards/p10-ifx-i2d/d1-remote-snapshot.json',
    [string] $RehearsalPath = 'artifacts/guards/p10-ifx-i2d/d4-rehearsal/rehearsal.json',
    [string] $OutputDirectory = 'artifacts/guards/p10-ifx-i2d/d5-review'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Full([string] $Relative) { [IO.Path]::GetFullPath((Join-Path $root $Relative)) }
function Bound([string] $Relative) { [ordered]@{ path = $Relative.Replace('\', '/'); sha256 = Get-IFXI2CFileSha256 (Full $Relative) } }
$snapshot = Get-Content -Raw -LiteralPath (Full $SnapshotPath) | ConvertFrom-Json -Depth 50
$rehearsal = Get-Content -Raw -LiteralPath (Full $RehearsalPath) | ConvertFrom-Json -Depth 50
$specRelative = 'docs/guards/candidates/ifx-i2d/pr-spec.json'
$spec = Get-Content -Raw -LiteralPath (Full $specRelative) | ConvertFrom-Json -Depth 20
$entry = @($spec.sets)[0]
Assert-IFXI2C ($snapshot.status -ceq 'pass') 'The D1 snapshot did not pass.'
Assert-IFXI2C ($rehearsal.status -ceq 'pass') 'The D4 rehearsal did not pass.'
Assert-IFXI2C ($rehearsal.specSha256 -ceq (Get-IFXI2CFileSha256 (Full $specRelative))) 'The spec changed after the rehearsal.'
$out = Full $OutputDirectory
Assert-IFXI2C (-not [IO.Directory]::Exists($out)) "The review packet already exists: $out"
[void][IO.Directory]::CreateDirectory($out)
$groups = [ordered]@{}
foreach ($p in @($entry.copy)) { $g = ($p.Split('/') | Select-Object -Skip 3 -First 1); if (-not $groups.Contains($g)) { $groups[$g] = 0 }; $groups[$g]++ }
$authored = [ordered]@{}
foreach ($p in @($entry.authored)) { $f = "docs/guards/candidates/ifx-i2d/pr/P1/$p"; $authored[$p] = Bound $f }
$remote = @(
    [ordered]@{ step = 'D6'; action = "Rebuild the head on the then-current main, push $($entry.branch) and open the PR to main"; then = 'the operator reports the checks or asks for one GET read' },
    [ordered]@{ step = 'D7'; action = 'Merge with a merge commit after 13/13, --match-head-commit'; then = 'GET verify' },
    [ordered]@{ step = 'D8'; action = 'Post-state record, merge main into the development branch (README conflict by rule), receipt'; then = 'local' },
    [ordered]@{ step = 'D9'; action = 'Push the development branch (fast-forward)'; then = 'GET verify' })
$packet = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2d-review-packet'; planId = '20261001-v4-ifx-i2d-publish-trusted-inputs'; step = 'D5'
    createdAtUtc = [DateTime]::UtcNow.ToString('o'); repositoryHead = (Invoke-IFXI2CGit $root @('rev-parse', 'HEAD'))[0].Trim()
    plan = Bound 'docs/guards/plans/20261001-v4-ifx-i2d-publish-trusted-inputs.plan.json'; snapshot = Bound $SnapshotPath; rehearsal = Bound $RehearsalPath; spec = Bound $specRelative
    main = [string]$snapshot.heads.main; sourceCommit = [string]$spec.sourceCommit; rulesetCanonicalSha256 = [string]$snapshot.ruleset.canonicalSha256
    published = [ordered]@{ copied = @($entry.copy).Count; authored = $authored; byDirectory = $groups; bundleManifestSha256 = 'a2f619a31c2751949058812d73fdf6a6b6142832c85e772d23a714f40304e372'; reviewSha256 = '38eb775a885996d0ab092dc1f4fe32e600a3fdb0997bce4a018e698eed93e24d'; composedPackageHash = [string]$rehearsal.expectedPackageHash }
    rehearsalSteps = @($rehearsal.steps | ForEach-Object { [ordered]@{ id = $_.id; exit = $_.exit; asExpected = $_.asExpected } })
    notRunLocally = @($rehearsal.notRunLocally); remoteSteps = $remote
    questions = @('Accept the publication pull request (the 298 copied files, the main README and its V3 plan) as prepared?', 'After acceptance, D6 (push and open the PR) needs its own authorization.')
}
Write-IFXI2CJson (Join-Path $out 'review-packet.json') $packet
$md = [Text.StringBuilder]::new(); function L([string] $Text = '') { [void]$md.AppendLine($Text) }
L '# IFX I2-D review packet (D5)'; L
L "Plan ``20261001-v4-ifx-i2d-publish-trusted-inputs``. Repository head ``$($packet.repositoryHead)``."; L
L '## Remote state (D1, GET only)'; L
L "- ``main`` = ``codex/guards-principles-plan`` = ``$($packet.main)``; default branch ``main``; no open pull request; ``main``'s ``v4-adoption`` holds only the README."
L "- Ruleset 23459908 canonical SHA-256 ``$($packet.rulesetCanonicalSha256)``, equal to the I2-C snapshot."; L
L '## What main receives'; L
L "One pull request, ``$($entry.branch)``. Every copied file is byte-identical to its development-branch source blob at ``$($spec.sourceCommit.Substring(0, 8))``:"; L
L '| Directory | Files |'; L '| --- | --- |'
foreach ($k in $groups.Keys) { L "| ``docs/guards/v4-adoption/$k/`` | $($groups[$k]) |" }
L; L "- ``extensions/ifx/0.5.2/``: the certified bundle (manifest ``a2f619a3…``: the manifest plus 262 package files) and the accepted review ``38eb775a…``."
L "- Authored: the ``main`` edition of ``docs/guards/v4-adoption/README.md`` and the V3 plan pair ``$((@($entry.authored) | Where-Object { $_ -like '*.plan.json' }) -join '')`` (it lists all $(@($entry.copy).Count + @($entry.authored).Count) paths, as V3 Diff matches paths exactly)."
L '- Not published (RD1, RD3): the design notes `plans/`, the development edition of the README, `docs/guards/TODO.md`.'; L
L '## Rehearsal (D4)'; L
L "Status **$($rehearsal.status)**. The V3 checks came from main's own trusted runner; the publication checks ran on fresh checkouts with ``core.autocrlf`` true (as hosted Windows runners) and false."; L
L '| Step | Exit | As expected |'; L '| --- | --- | --- |'
foreach ($s in @($rehearsal.steps)) { L "| ``$($s.id)`` | $($s.exit) | $($s.asExpected) |" }
L; L "The published bundle, copied out of the checkout as the specimen does and composed with the 1.1.6 base under the published review, gives package ``$($rehearsal.expectedPackageHash.Substring(0, 8))…``, the A3-10a package."
L; L "Not run locally (CI runs them on the PR): $(@($rehearsal.notRunLocally) -join ', ')."; L
L '## Remote steps after acceptance (each separately authorized)'; L
L '| Step | Action | Then |'; L '| --- | --- | --- |'
foreach ($r in $remote) { L "| $($r.step) | $($r.action) | $($r.then) |" }
L; L '## Questions'; L
foreach ($q in $packet.questions) { L "- $q" }
[IO.File]::WriteAllText((Join-Path $out 'review.md'), $md.ToString(), [Text.UTF8Encoding]::new($false))
Write-Output "D5 review packet: $(Join-Path $out 'review-packet.json') $((Get-IFXI2CFileSha256 (Join-Path $out 'review-packet.json')).Substring(0, 12))"
