# IFX I2-B amendment A2 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A2-10a: the C6e composition of
# V4 Guards 1.1.6 + ifx_profile 0.5.1 with the accepted production review record (the A1-8a runner of
# candidates/ifx-i2b-050a with the 0.5.1 roots, identities and step labels); successor of
# candidates/ifx-rebind-116/Invoke-IFX116S7Preparation.ps1 and Invoke-IFX116S7HostRuns.ps1 (unchanged).
# Two clean clones detached at the certified commit: the clean one also gets one evidence production, staged the way
# the trusted-base workflow will stage it. Installed-Host runs: clean Pre passes; a deliberate import fault blocks
# with IMPORT-DIRECTION; clean Post on staged evidence passes; the dependency run passes; Post without staged
# evidence fails closed. Protected roots and Git facts are re-checked after the runs.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$C6dDecisionPath,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$ReviewPacketPath,
    [Parameter(Mandatory)][string]$ExpectedTargetCommit,
    [Parameter(Mandatory)][string]$ExpectedBundleManifestSha256,
    [Parameter(Mandatory)][string]$ExpectedReviewPacketSha256,
    [Parameter(Mandatory)][string]$ExpectedReviewRecordSha256,
    [Parameter(Mandatory)][string]$ExpectedC6dDecisionSha256,
    [Parameter(Mandatory)][string]$EvidenceOutputRoot,
    [Parameter(Mandatory)][string]$DecisionPath,
    [string]$RuntimeRoot = 'D:/IFX-Root/guard-runtime',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$ExpectedBaseArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ExpectedBaseReceiptSha256 = 'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw $Message }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function TextHash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
function Write-Log([string]$Path, $Lines) { [IO.File]::WriteAllText($Path, ((@($Lines) | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false)) }
function Full-File([string]$Path, [string]$Label) { $f = [IO.Path]::GetFullPath($Path); if (-not [IO.File]::Exists($f)) { Fail "$Label is missing: $f" }; $f }
function Absent([string]$Path, [string]$Label) { $f = [IO.Path]::GetFullPath($Path); if ([IO.File]::Exists($f) -or [IO.Directory]::Exists($f)) { Fail "$Label must be absent: $f" }; $f }
function Is-Under([string]$Path, [string]$Root) { $r = [IO.Path]::GetRelativePath($Root, $Path); $r -eq '.' -or (-not [IO.Path]::IsPathRooted($r) -and $r -ne '..' -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)")) }
function Get-InventoryDigest([string]$Root, [string[]]$Skip = @()) {
    # Ordered path|size|sha256 lines; $Skip excludes Target subtrees the producers own (ignored build output).
    $lines = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        $rel = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        if (@($Skip | Where-Object { $rel.StartsWith($_, [StringComparison]::Ordinal) }).Count -eq 0) { "$rel|$($_.Length)|$(Hash $_.FullName)" }
    } | Sort-Object -CaseSensitive)
    [ordered]@{ fileCount = $lines.Count; sha256 = (TextHash (($lines -join "`n") + "`n")) }
}
function Git-Facts([string]$Root) {
    $head = (& git -C $Root rev-parse HEAD).Trim(); & git -C $Root symbolic-ref -q HEAD *> $null; $detached = $LASTEXITCODE -ne 0
    [ordered]@{ root = $Root; head = $head; detached = $detached; status = @(& git -C $Root status --porcelain=v1 --untracked-files=all) }
}
function Invoke-Host([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $logRoot $Name; [void][IO.Directory]::CreateDirectory($log)
    $info = [Diagnostics.ProcessStartInfo]::new('dotnet'); $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    [void]$info.ArgumentList.Add($hostDll); foreach ($a in $Arguments) { [void]$info.ArgumentList.Add($a) }
    $p = [Diagnostics.Process]::Start($info); $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync(); $p.WaitForExit()
    $stdout = $out.GetAwaiter().GetResult(); $stderr = $err.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $log 'stdout.txt'), $stdout, [Text.UTF8Encoding]::new($false)); [IO.File]::WriteAllText((Join-Path $log 'stderr.txt'), $stderr, [Text.UTF8Encoding]::new($false))
    $doc = $null; foreach ($text in @($stdout, $stderr)) { if ([string]::IsNullOrWhiteSpace($text)) { continue }; try { $doc = $text | ConvertFrom-Json -AsHashtable -Depth 100; break } catch {} }
    [ordered]@{ exitCode = $p.ExitCode; result = $doc; stdoutSha256 = TextHash $stdout }
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$runtime = [IO.Path]::GetFullPath($RuntimeRoot)
$bundle = [IO.Path]::GetFullPath($BundleRoot); $manifestFile = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$c6dFile = Full-File $C6dDecisionPath 'C6d decision'; $reviewFile = Full-File $ReviewRecordPath 'Production review'; $packetFile = Full-File $ReviewPacketPath 'Review packet'
$base = Join-Path $runtime 'releases/v4-guards-1.1.6'; $baseReceipt = Full-File (Join-Path $runtime 'receipts/v4-guards-1.1.6.install.json') 'Base receipt'
$archive = Full-File $(if ([IO.Path]::IsPathFullyQualified($BaseArchivePath)) { $BaseArchivePath } else { Join-Path $repo $BaseArchivePath }) 'Base archive'
$install = Absent (Join-Path $runtime 'releases/v4-guards-1.1.6-ifx-0.5.1') 'Composed installation'
$receipt = Absent (Join-Path $runtime 'receipts/v4-guards-1.1.6-ifx-0.5.1.compose.json') 'Composition receipt'
$state = Absent (Join-Path $runtime 'state/ifx-a210-051') 'StateRoot'; $evidence = Absent (Join-Path $runtime 'evidence/ifx-a210-051') 'EvidenceRoot'
$clean = Absent (Join-Path $runtime 'fixtures/ifx-a210-clean-051') 'Clean worktree'; $violating = Absent (Join-Path $runtime 'fixtures/ifx-a210-violating-051') 'Violating worktree'
$evidenceOutput = Absent $EvidenceOutputRoot 'A2-10a evidence output'; $decisionFull = Absent $DecisionPath 'A2-10a decision'
$roots = @($bundle, $base, $install, $state, $evidence, $clean, $violating, $evidenceOutput)
for ($i = 0; $i -lt $roots.Count; $i++) { for ($j = $i + 1; $j -lt $roots.Count; $j++) { if ((Is-Under $roots[$i] $roots[$j]) -or (Is-Under $roots[$j] $roots[$i])) { Fail "Overlapping roots: $($roots[$i]) / $($roots[$j])" } } }

# 1. The accepted identity (A1-7).
$ids = [ordered]@{ bundleManifest = Hash $manifestFile; reviewPacket = Hash $packetFile; reviewRecord = Hash $reviewFile; c6dDecision = Hash $c6dFile; baseArchive = Hash $archive; baseReceipt = Hash $baseReceipt }
$expected = [ordered]@{ bundleManifest = $ExpectedBundleManifestSha256; reviewPacket = $ExpectedReviewPacketSha256; reviewRecord = $ExpectedReviewRecordSha256; c6dDecision = $ExpectedC6dDecisionSha256; baseArchive = $ExpectedBaseArchiveSha256; baseReceipt = $ExpectedBaseReceiptSha256 }
foreach ($k in $expected.Keys) { if ($ids[$k] -cne $expected[$k]) { Fail "$k SHA-256 mismatch." } }
$c6d = Read-Json $c6dFile; $review = Read-Json $reviewFile; $packet = Read-Json $packetFile; $manifest = Read-Json $manifestFile
if ($c6d.status -cne 'pass' -or $c6d.decision -cne 'c6d-exact-bundle-human-review-accepted' -or $c6d.targetCommit -cne $ExpectedTargetCommit -or $packet.targetCommit -cne $ExpectedTargetCommit -or
    $review.scope -cne 'production' -or $review.decision -cne 'accepted' -or $review.acceptedBy.authorityId -cne 'xiaolong-feng' -or $review.bundleManifestSha256 -cne $ids.bundleManifest -or
    $manifest.baseVersion -cne '1.1.6' -or $manifest.version -cne '0.5.1' -or $c6d.acceptedEvidence.productionReviewRecord.sha256 -cne $ids.reviewRecord) { Fail 'Accepted A2-9 production identity is invalid.' }
$verifier = Join-Path $base 'package/core/distribution/Test-V4ComposedInstallation.ps1'; $composer = Join-Path $base 'package/core/distribution/Compose-V4Extension.ps1'
$baseText = @(& $verifier -InstallRoot $base -ReceiptPath $baseReceipt 2>&1); if ($LASTEXITCODE -ne 0) { Fail "Base verification failed: $($baseText -join ' ')" }
$baseProof = ($baseText -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($baseProof.status -cne 'pass' -or $baseProof.kind -cne 'base-release' -or $baseProof.receiptSha256 -cne $ids.baseReceipt) { Fail 'Base proof mismatch.' }

# 2. Two clean clones detached at the certified commit (not worktrees: the evidence producers require a .git
# directory); one deliberate import fault.
[void][IO.Directory]::CreateDirectory($evidenceOutput); $logRoot = Join-Path $evidenceOutput 'host-runs'
foreach ($wt in @($clean, $violating)) {
    $o = @(& git clone --no-local --quiet -c core.longpaths=true $repo $wt 2>&1); $code = $LASTEXITCODE
    if ($code -eq 0) { $o += @(& git -C $wt -c advice.detachedHead=false checkout --quiet --detach $ExpectedTargetCommit 2>&1); $code = $LASTEXITCODE }
    Write-Log (Join-Path $evidenceOutput "$([IO.Path]::GetFileName($wt))-clone.log") $o; if ($code -ne 0) { Fail "Target clone failed: $wt" }
}
$faultRelative = 'src/Modules/CRM/IFX.Modules.CRM.Domain/A210Fault.cs'
[IO.File]::WriteAllText((Join-Path $violating $faultRelative), "using IFX.Modules.CRM.Contracts;`n`nnamespace IFX.Modules.CRM.Domain;`n`ninternal sealed class A210Fault;`n", [Text.UTF8Encoding]::new($false))
$cleanFacts = Git-Facts $clean; $violatingFacts = Git-Facts $violating
if ($cleanFacts.head -cne $ExpectedTargetCommit -or $violatingFacts.head -cne $ExpectedTargetCommit -or -not $cleanFacts.detached -or -not $violatingFacts.detached -or
    @($cleanFacts.status).Count -ne 0 -or (@($violatingFacts.status) -join '|') -cne "?? $faultRelative") { Fail 'Worktrees are not the expected clean and single-fault checkouts.' }

# 3. One evidence production on the clean worktree (as the workflow produces it), then staging per Post root.
$production = Join-Path $evidenceOutput 'production.json'
$produced = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Produce -TargetRoot $clean -RunRecordPath $production 2>&1)
Write-Log (Join-Path $evidenceOutput 'production.log') $produced; if ($LASTEXITCODE -ne 0) { Fail "Evidence production failed; see production.log" }
if (@(& git -C $clean status --porcelain=v1 --untracked-files=all).Count -ne 0) { Fail 'Evidence production changed the tracked or unignored clean worktree.' }
# The clean Target is protected by its tree and a clean status (production writes only ignored build output).
$pre =[ordered]@{ baseInstallation = Get-InventoryDigest $base; bundle = Get-InventoryDigest $bundle; cleanTracked = (& git -C $clean rev-parse 'HEAD^{tree}').Trim(); violatingTarget = Get-InventoryDigest $violating @('.git') }
Write-Json (Join-Path $evidenceOutput 'pre-inventories.json') ([ordered]@{ formatVersion = 1; roots = $pre })

# 4. Production composition with the accepted review record (no synthetic fixture).
foreach ($d in @($state, $evidence)) { [void][IO.Directory]::CreateDirectory((Join-Path $d 'compose')) }
$composeText = @(& $composer -BaseInstallRoot $base -BaseReceiptPath $baseReceipt -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $reviewFile -OutputInstallRoot $install `
    -CompositionReceiptPath $receipt -TargetRoot $clean -StateRoot (Join-Path $state 'compose') -EvidenceRoot (Join-Path $evidence 'compose') 2>&1)
Write-Log (Join-Path $evidenceOutput 'compose.log') $composeText; if ($LASTEXITCODE -ne 0) { Fail 'Production composition failed; see compose.log' }
$verifyText = @(& $verifier -InstallRoot $install -ReceiptPath $receipt -BaseReceiptPath $baseReceipt 2>&1)
Write-Log (Join-Path $evidenceOutput 'composition-verification.log') $verifyText; if ($LASTEXITCODE -ne 0) { Fail 'Composition verification failed.' }
$compositionProof = ($verifyText -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($compositionProof.status -cne 'pass' -or $compositionProof.kind -cne 'local-extension-composition' -or $compositionProof.scope -cne 'production' -or $compositionProof.bundleManifestSha256 -cne $ids.bundleManifest) { Fail 'Production composition proof mismatch.' }
$hostDll = Join-Path $install 'host/v4-guards.dll'; $package = Join-Path $install 'package'
$packageBefore = Get-InventoryDigest $package
$profileFile = Join-Path $package 'profiles/catalog/ifx_profile/profile.json'; $profileSha = Hash $profileFile; $profile = Read-Json $profileFile
$version = Invoke-Host 'version' @('version'); if ($version.exitCode -ne 0 -or $version.result.version -cne '1.1.6') { Fail 'Installed Host version is not 1.1.6.' }

# 5. Installed-Host runs, each with its own StateRoot and EvidenceRoot.
$specs = @(
    [ordered]@{ id = 'pre-clean'; stage = 'pre'; target = $clean; staged = $false; deps = $false; exit = 0 }
    [ordered]@{ id = 'pre-violating'; stage = 'pre'; target = $violating; staged = $false; deps = $false; exit = 16 }
    [ordered]@{ id = 'post-staged'; stage = 'post'; target = $clean; staged = $true; deps = $false; exit = 0 }
    [ordered]@{ id = 'dependency-post-staged'; stage = 'post'; target = $clean; staged = $true; deps = $true; exit = 0 }
    [ordered]@{ id = 'post-unstaged'; stage = 'post'; target = $clean; staged = $false; deps = $false; exit = $null })
$cases = [ordered]@{}
foreach ($s in $specs) {
    $st = Join-Path $state $s.id; $ev = Join-Path $evidence $s.id; [void][IO.Directory]::CreateDirectory($st)
    if ($s.staged) {
        $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Stage -TargetRoot $clean -RunRecordPath $production -EvidenceRoot $ev 2>&1)
        Write-Log (Join-Path $evidenceOutput "stage-$($s.id).log") $o; if ($LASTEXITCODE -ne 0) { Fail "Staging failed: $($s.id)" }
    } else { [void][IO.Directory]::CreateDirectory($ev) }
    $a = @('stage', 'run', '--stage', $s.stage, '--package-root', $package, '--target-root', $s.target, '--state-root', $st, '--evidence-root', $ev, '--profile', 'ifx_profile')
    if ($s.deps) { $a += '--with-dependencies' }
    $run = Invoke-Host $s.id $a
    if ($null -eq $run.result -or ($null -ne $s.exit -and $run.exitCode -ne $s.exit)) { Fail "Host $($s.id) returned exit $($run.exitCode)." }
    $r = $run.result
    $row = [ordered]@{ id = $s.id; stage = $s.stage; target = $s.target; staged = $s.staged; withDependencies = $s.deps; hostExitCode = $run.exitCode; status = [string]$r.status; exitCategory = [string]$r.exitCategory
        executedStages = @($r.executedStages); moduleCount = @($r.moduleResults).Count; passedModuleCount = @($r.moduleResults | Where-Object { $_.status -ceq 'pass' }).Count
        failedModules = @($r.moduleResults | Where-Object { $_.status -cne 'pass' } | ForEach-Object { [ordered]@{ moduleId = [string]$_.moduleId; status = [string]$_.status } })
        findings = @($r.findings); coverageClaimCount = @($r.coverage).Count; allCoverageNonVacuous = (@($r.coverage | Where-Object { [int]$_.matched -lt [int]$_.minimum -or [int]$_.matched -lt 1 }).Count -eq 0)
        profileSha256 = [string]$r.profile.sha256; packageHash = [string]$r.authorityHashes.package; stageResultSha256 = $run.stdoutSha256 }
    if ($s.id -in @('pre-clean', 'pre-violating', 'post-staged')) {
        $project = Invoke-Host "project-$($s.id)" @('query', 'project', '--package-root', $package, '--target-root', $s.target, '--state-root', $st, '--evidence-root', $ev)
        $projectId = [string]$project.result['project']['projectId']
        $runs = Invoke-Host "runs-$($s.id)" @('query', 'runs', '--package-root', $package, '--state-root', $st, '--evidence-root', $ev, '--project', $projectId)
        $evq = Invoke-Host "evidence-$($s.id)" @('query', 'evidence', '--package-root', $package, '--state-root', $st, '--evidence-root', $ev, '--project', $projectId, '--run', [string]$r.runId)
        $listed = @($runs.result['runs'] | Where-Object { [string]$_['runId'] -ceq [string]$r.runId })
        $row.hostQueriesAgree = ($project.exitCode -eq 0 -and $runs.exitCode -eq 0 -and $evq.exitCode -eq 0 -and $listed.Count -eq 1 -and [string]$listed[0]['status'] -ceq $row.status -and
            [int]$listed[0]['findingCount'] -eq @($row.findings).Count -and [int]$listed[0]['coverageCount'] -eq $row.coverageClaimCount -and [string]$listed[0]['resultSha256'] -ceq [string]$evq.result['resultSha256'] -and
            [string]$evq.result['stageResult']['status'] -ceq $row.status)
    }
    $cases[$s.id] = $row
}

# 6. Checks.
$c = $cases['pre-clean']; $v = $cases['pre-violating']; $p = $cases['post-staged']; $d = $cases['dependency-post-staged']; $u = $cases['post-unstaged']
$lockConsumers = @('ifx-c1-type-provenance', 'ifx-c1-evaluated-reference', 'ifx-solution-evidence', 'ifx-assembly-evidence', 'ifx-frontend-evidence', 'ifx-database-evidence')
$fault = @($v.findings | Where-Object { $_.ruleId -ceq 'IMPORT-DIRECTION' -and $_.detectorId -ceq 'ifx-source-policy' -and $_.severity -ceq 'blocking' -and ([string]$_.subject).StartsWith("$faultRelative`:1:") })
$unstagedFailed = @($u.failedModules | ForEach-Object { $_.moduleId })
$checks = [ordered]@{
    cleanPrePass = ($c.status -ceq 'pass' -and $c.moduleCount -eq 10 -and $c.passedModuleCount -eq 10 -and @($c.findings).Count -eq 0 -and $c.coverageClaimCount -eq 22 -and $c.allCoverageNonVacuous)
    violatingPreBlocks = ($v.status -ceq 'fail' -and $v.exitCategory -ceq 'findings-blocking' -and $v.moduleCount -eq 10 -and ((@($v.failedModules | ForEach-Object { $_.moduleId })) -join '|') -ceq 'ifx-source-policy' -and $fault.Count -eq 1 -and @($v.findings).Count -eq 1)
    stagedPostPass = ($p.status -ceq 'pass' -and $p.moduleCount -eq 27 -and $p.passedModuleCount -eq 27 -and @($p.findings).Count -eq 0 -and $p.coverageClaimCount -eq 57 -and $p.allCoverageNonVacuous)
    dependencyPostPass = ($d.status -ceq 'pass' -and $d.moduleCount -eq 37 -and @($d.findings).Count -eq 0 -and $d.coverageClaimCount -eq 79 -and ($d.executedStages -join ',') -ceq 'bootstrap,analysis,pre,post')
    # The Host stops at the first missing prerequisite (architecture-conformance reads the staged assembly
    # manifest); each lock consumer's missing-staging case is proven by the C6c staged-evidence controls.
    unstagedPostFailsClosed = ($u.status -ceq 'error' -and $u.exitCategory -ceq 'prerequisite-missing' -and $u.hostExitCode -ne 0 -and $u.passedModuleCount -eq 0 -and
        @($unstagedFailed | Where-Object { $_ -notin (@($lockConsumers) + 'architecture-conformance') }).Count -eq 0)
    profileIdentity = ($profile.version -ceq '0.5.1' -and @($cases.Values | Where-Object { $_.profileSha256 -cne $profileSha }).Count -eq 0)
    hostQueriesAgree = ($c.hostQueriesAgree -and $v.hostQueriesAgree -and $p.hostQueriesAgree)
}
$post = [ordered]@{ baseInstallation = Get-InventoryDigest $base; bundle = Get-InventoryDigest $bundle; cleanTracked = (& git -C $clean rev-parse 'HEAD^{tree}').Trim(); violatingTarget = Get-InventoryDigest $violating @('.git') }
$checks.protectedRootsUnchanged = ($post.baseInstallation.sha256 -ceq $pre.baseInstallation.sha256 -and $post.bundle.sha256 -ceq $pre.bundle.sha256 -and $post.violatingTarget.sha256 -ceq $pre.violatingTarget.sha256 -and (Get-InventoryDigest $package).sha256 -ceq $packageBefore.sha256)
$checks.gitFactsUnchanged = (@(& git -C $clean status --porcelain=v1 --untracked-files=all).Count -eq 0 -and (@(& git -C $violating status --porcelain=v1 --untracked-files=all) -join '|') -ceq "?? $faultRelative" -and
    (& git -C $clean rev-parse HEAD).Trim() -ceq $ExpectedTargetCommit -and (& git -C $violating rev-parse HEAD).Trim() -ceq $ExpectedTargetCommit)
$status = if (@($checks.Values | Where-Object { -not $_ }).Count -eq 0) { 'pass' } else { 'fail' }
$verification = Join-Path $evidenceOutput 'host-verification.json'
Write-Json $verification ([ordered]@{ formatVersion = 1; status = $status; verification = 'installed-host-and-host-query-match'
    installedRuntime = [ordered]@{ installRoot = $install; packageHash = $c.packageHash; profileId = 'ifx_profile'; profileVersion = [string]$profile.version; profileSha256 = $profileSha }
    cases = $cases; checks = $checks; preInventories = $pre; postInventories = $post; unstagedPostFailedModules = @($u.failedModules) })
Write-Json $decisionFull ([ordered]@{ formatVersion = 1; status = $status; decision = $(if ($status -ceq 'pass') { 'a2-10a-composition-accepted' } else { 'a2-10a-composition-stopped' })
    planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; step = 'A2-10a'; targetCommit = $ExpectedTargetCommit; identities = $ids; baseProof = $baseProof; compositionProof = $compositionProof
    composition = [ordered]@{ installRoot = $install; receipt = [ordered]@{ path = $receipt; sha256 = Hash $receipt }; packageHash = $c.packageHash; bundleManifestSha256 = $ids.bundleManifest; reviewRecordSha256 = $ids.reviewRecord }
    production = [ordered]@{ path = $production; sha256 = Hash $production }; hostVerificationSha256 = Hash $verification; checks = $checks
    boundary = [ordered]@{ installedWebUi = 'deferred-to-p10-gate-successor'; p10GatePassed = $false; activated = $false; cutover = $false; workflowInstalled = $false } })
Write-Output "IFX 0.5.1 C6e composition (A2-10a) $status`: $decisionFull"
if ($status -cne 'pass') { exit 1 }
