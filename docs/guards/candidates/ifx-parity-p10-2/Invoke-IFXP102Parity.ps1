[CmdletBinding()]
param(
    [string] $RepositoryRoot = 'D:/IFX-Root/IFX',
    [string] $ReferenceRoot = 'D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-clean-042',
    [string] $ViolationRoot = 'D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-violating-042',
    [string] $InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2-c6e-r1',
    [string] $ReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4-ifx-0.4.2-c6e-r1.compose.json',
    [string] $BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4.install.json',
    [string] $BundleRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/recovery-042/authorized-refresh/formal-candidate-a/97129b4b44874b05956bcb6a4c95d4e9/bundle',
    [string] $C6eDecisionPath = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/c6e-r1-042/c6e-r1-decision.json',
    [string] $C6cWindowsRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/c6c-recovery-042-full/windows',
    [string] $OutputRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/p10-2-parity-042',
    [string] $BuildRoot = 'D:/IFX-Root/guard-runtime/build/p10-2-parity-042',
    [string] $RuntimeRoot = 'D:/IFX-Root/guard-runtime/evidence/p10-2-parity-042'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = [ordered]@{
    targetCommit = '40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82'
    c6eDecision = '94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22'
    v3Inventory = '087a85f86561294cbc36223de40a6821aaa1de458164f715e06fa2404b807102'
    v3Policy = 'b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5'
    v3TrustedComponents = '2213db9f5d217bca12144b667d1af5fcfabf1ca707186dedadefaa75d62202be'
    package = '739e2035b24f42a0d09719bd78d010de9320452086109fbdd95c064f67e5a6c1'
    receipt = '51f5fc11b7fa36e14d83eade699979e31de2d06d3134af9caad9a329fd043345'
    bundleManifest = '82eb0c5db8ec3779bc10a43b89f0a9235e38d02819745e8f42bffa7fd9635ee5'
    profile = 'b7aac25f5cefbaf4d99023a71e29130da283debbe7446e160b42d7f1cb385023'
    caseManifest = '22d3b8b4ed018bfcfa1456402c6fefc2e53ce730795ed573f77022fb1e247eae'
    c6cSummary = '858b69949c0febc386557f8bb70287d2abe3a7c2af56e6f5aa20b2fbc7de9ff8'
    pwsh = '7.6.6'
    dotnet = '10.0.303'
    git = 'git version 2.49.0.windows.1'
}
$moduleCapture = [ordered]@{
    'ifx-domain-reference' = 'c1b'
    'ifx-package-reference' = 'c1c'
    'ifx-ring-graph' = 'c1d'
    'ifx-ownership-graph' = 'c1e'
    'ifx-provider-cycle' = 'c1f'
    'ifx-embedded-adapter' = 'c1g'
    'ifx-source-policy' = 'c1h'
    'ifx-project-name' = 'c1j'
    'ifx-reference-cycle' = 'c1n'
    'ifx-injection' = 'c1o'
}

function Fail([string] $Message) { throw $Message }
function Sha([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Sha([string] $Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([Convert]::ToHexString($algorithm.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Value)))).ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    $json = (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n")
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Full-File([string] $Path, [string] $Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($full)) { Fail "$Label is missing: $full" }
    $full
}
function Full-Directory([string] $Path, [string] $Label) {
    $full = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Path))
    if (-not [IO.Directory]::Exists($full)) { Fail "$Label is missing: $full" }
    $full
}
function Absent([string] $Path, [string] $Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if ([IO.File]::Exists($full) -or [IO.Directory]::Exists($full)) { Fail "$Label must be absent: $full" }
    $full
}
function Fingerprint([string] $Root) {
    if (-not [IO.Directory]::Exists($Root)) { return '<absent>' }
    @((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Sha $_.FullName)"
    })) -join "`n"
}
function Root-Inventory([string] $Root, [string[]] $RelativeRoots) {
    $files = [Collections.Generic.List[object]]::new()
    foreach ($relative in $RelativeRoots) {
        $start = Join-Path $Root $relative
        foreach ($file in @(Get-ChildItem -LiteralPath $start -File -Recurse -Force)) {
            $files.Add([ordered]@{path=[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/');size=[long]$file.Length;sha256=Sha $file.FullName})
        }
    }
    $ordered = @($files | Sort-Object { [string]$_.path })
    $lines = @($ordered | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" })
    [ordered]@{fileCount=$ordered.Count;inventorySha256=Text-Sha (($lines -join "`n") + "`n")}
}
function Run-Captured([string] $Name, [string] $File, [string[]] $Arguments, [string] $WorkingDirectory, [string] $LogRoot, [hashtable] $Environment = @{}) {
    [void][IO.Directory]::CreateDirectory($LogRoot)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$info.ArgumentList.Add($argument) }
    foreach ($entry in $Environment.GetEnumerator()) { $info.Environment[[string]$entry.Key] = [string]$entry.Value }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    $started = [DateTimeOffset]::Now; $watch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { Fail "Failed to start $Name." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit(); $watch.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult(); $stderr = $stderrTask.GetAwaiter().GetResult()
    $stdoutPath = Join-Path $LogRoot 'stdout.txt'; $stderrPath = Join-Path $LogRoot 'stderr.txt'
    [IO.File]::WriteAllText($stdoutPath,$stdout,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath,$stderr,[Text.UTF8Encoding]::new($false))
    $result = [ordered]@{name=$Name;startedAt=$started.ToString('o');elapsedSeconds=[math]::Round($watch.Elapsed.TotalSeconds,3);exitCode=$process.ExitCode;stdoutSha256=Sha $stdoutPath;stderrSha256=Sha $stderrPath}
    $process.Dispose(); $result
}

$repo = Full-Directory $RepositoryRoot 'RepositoryRoot'
$reference = Full-Directory $ReferenceRoot 'ReferenceRoot'
$violation = Full-Directory $ViolationRoot 'ViolationRoot'
$install = Full-Directory $InstallRoot 'InstallRoot'
$receipt = Full-File $ReceiptPath 'Composition receipt'
$baseReceipt = Full-File $BaseReceiptPath 'Base receipt'
$bundle = Full-Directory $BundleRoot 'BundleRoot'
$decisionPath = Full-File $C6eDecisionPath 'C6e-R1 decision'
$windows = Full-Directory $C6cWindowsRoot 'C6c Windows evidence'
$output = Absent $OutputRoot 'OutputRoot'
$build = Absent $BuildRoot 'BuildRoot'
$runtime = Absent $RuntimeRoot 'RuntimeRoot'
$caseManifestPath = Full-File (Join-Path $windows 'case-manifest.json') 'C6c case manifest'
$c6cSummaryPath = Full-File (Join-Path $windows 'summary.json') 'C6c summary'
$v3PolicyPath = Full-File (Join-Path $reference 'docs/guards/V3_ifx/stages/post/policy/layerguard.json') 'V3 policy'
$v3BaselinePath = Full-File (Join-Path $reference 'docs/guards/V3_ifx/stages/post/policy/baselines/plan05.json') 'V3 baseline'
$v3TrustedPath = Full-File (Join-Path $reference 'docs/guards/V3_ifx/shared/trusted-components.json') 'V3 trusted components'
$bundleManifestPath = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$profilePath = Full-File (Join-Path $install 'package/profiles/catalog/ifx_profile/profile.json') 'Installed IFX Profile'
$toolchain = [ordered]@{pwsh=$PSVersionTable.PSVersion.ToString();dotnet=(& dotnet --version).Trim();git=(& git --version).Trim()}
if ($toolchain.pwsh -cne $expected.pwsh -or $toolchain.dotnet -cne $expected.dotnet -or $toolchain.git -cne $expected.git) { Fail 'Frozen toolchain identity mismatch.' }

if ((Sha $decisionPath) -cne $expected.c6eDecision -or (Sha $receipt) -cne $expected.receipt -or
    (Sha $bundleManifestPath) -cne $expected.bundleManifest -or (Sha $profilePath) -cne $expected.profile -or
    (Sha $caseManifestPath) -cne $expected.caseManifest -or (Sha $c6cSummaryPath) -cne $expected.c6cSummary -or
    (Sha $v3PolicyPath) -cne $expected.v3Policy -or (Sha $v3TrustedPath) -cne $expected.v3TrustedComponents) { Fail 'Frozen identity mismatch.' }
$decision = Get-Content -LiteralPath $decisionPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ($decision.status -cne 'pass' -or $decision.decision -cne 'c6e-r1-git-backed-repair-accepted') { Fail 'C6e-R1 is not accepted.' }
$referenceHead = (& git -C $reference rev-parse HEAD).Trim()
$referenceStatus = @(& git -C $reference status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0 -or $referenceHead -cne $expected.targetCommit -or $referenceStatus.Count -ne 0) { Fail 'Reference worktree is not the clean certified commit.' }
$v3Pre = Root-Inventory $reference @('docs/guards/V3','docs/guards/V3_ifx')
if ($v3Pre.inventorySha256 -cne $expected.v3Inventory -or $v3Pre.fileCount -ne 562) { Fail 'V3/V3_ifx inventory mismatch.' }
$immutablePre = [ordered]@{
    reference = Text-Sha (Fingerprint $reference)
    install = Text-Sha (Fingerprint $install)
    bundle = Text-Sha (Fingerprint $bundle)
    c6cWindows = Text-Sha (Fingerprint $windows)
}

$verifier = Full-File (Join-Path $reference 'docs/guards/v4/core/distribution/Test-V4ComposedInstallation.ps1') 'Public composition verifier'
$verifyText = @(& $verifier -InstallRoot $install -ReceiptPath $receipt -BaseReceiptPath $baseReceipt 2>&1)
if ($LASTEXITCODE -ne 0) { Fail "Public composition verifier failed: $($verifyText -join "`n")" }
$compositionProof = ($verifyText -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($compositionProof.status -cne 'pass' -or $compositionProof.packageHash -cne $expected.package) { Fail 'Composed package identity mismatch.' }
$profileDocument = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100

$manifest = Get-Content -LiteralPath $caseManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$modules = @($moduleCapture.Keys)
$cases = @($manifest.cases | Where-Object { [string]$_.moduleId -in $modules } | Sort-Object { [string]$_.id })
$kindCounts = @{}; foreach ($group in @($cases | Group-Object { [string]$_.kind })) { $kindCounts[$group.Name] = $group.Count }
if ($cases.Count -ne 52 -or $kindCounts.clean -ne 10 -or $kindCounts.missing -ne 10 -or $kindCounts.zero -ne 10 -or $kindCounts.violation -ne 22) { Fail 'Production corpus cardinality mismatch.' }

$captureRecords = [Collections.Generic.List[object]]::new()
foreach ($captureId in @($moduleCapture.Values + @('c6c4') | Sort-Object -Unique)) {
    $capturePath = Full-File (Join-Path $windows "captures/$captureId.jsonl") "Capture $captureId"
    foreach ($line in @(Get-Content -LiteralPath $capturePath)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $record = $line | ConvertFrom-Json -AsHashtable -Depth 100
        if ([string]$record.moduleId -in $modules) { $record.captureId = $captureId; $captureRecords.Add($record) }
    }
}

$corpus = [Collections.Generic.List[object]]::new()
$targetBefore = @{}
$providerBefore = @{}
foreach ($case in $cases) {
    $matches = @($captureRecords | Where-Object { [string]$_.moduleId -ceq [string]$case.moduleId -and [string]$_.fixtureSha256 -ceq [string]$case.fixtureSha256 })
    if ($matches.Count -eq 0) { Fail "No raw capture for $($case.id)." }
    $unique = @($matches | Group-Object { "$($_.targetRoot)|$($_.inputSha256)|$(Text-Sha ([string]$_.output))" })
    if ($unique.Count -ne 1) { Fail "Ambiguous raw capture for $($case.id)." }
    $capture = $matches[0]
    $v4 = ([string]$capture.output) | ConvertFrom-Json -AsHashtable -Depth 100
    if ([string]$v4.status -cne [string]$case.actual.status -or [string]$v4.exitCategory -cne [string]$case.actual.exitCategory) { Fail "Captured V4 outcome drift: $($case.id)." }
    $target = [IO.Path]::GetFullPath([string]$capture.targetRoot)
    $fingerprint = Fingerprint $target
    if ($fingerprint -cne [string]$capture.targetAfter -or [string]$capture.targetBefore -cne [string]$capture.targetAfter) { Fail "Frozen Target fingerprint drift: $($case.id)." }
    $targetBefore[$target] = Text-Sha $fingerprint
    $installedAdapter = Full-File (Join-Path $install "package/modules/$($case.moduleId)/adapter.ps1") "Installed adapter $($case.moduleId)"
    $capturedAdapter = [IO.Path]::GetFullPath([string]$capture.executed)
    $windowsPrefix = $windows + [IO.Path]::DirectorySeparatorChar
    $suiteLocal = [IO.File]::Exists($capturedAdapter) -and $capturedAdapter.StartsWith($windowsPrefix,[StringComparison]::OrdinalIgnoreCase)
    $replayAdapter = if ($suiteLocal) { $capturedAdapter } else { $installedAdapter }
    $providerRoot = [IO.Path]::GetDirectoryName($replayAdapter)
    if ((Sha $replayAdapter) -cne (Sha $installedAdapter)) { Fail "Replay adapter differs from the receipted adapter: $($case.id)." }
    $providerFingerprint = Fingerprint $providerRoot
    if ($suiteLocal) { $providerBefore[$providerRoot] = Text-Sha $providerFingerprint }
    $corpus.Add([ordered]@{
        id=[string]$case.id;kind=[string]$case.kind;moduleId=[string]$case.moduleId;ruleId=$case.ruleId;claimIds=@($case.claimIds)
        fixtureSha256=[string]$case.fixtureSha256;captureId=[string]$capture.captureId;targetRoot=$target
        targetFingerprintSha256=Text-Sha $fingerprint;v4InputSha256=[string]$capture.inputSha256
        replay=[ordered]@{mode=$(if($suiteLocal){'suite-local-provider'}else{'receipted-installation'});adapterPath=$replayAdapter;adapterSha256=Sha $replayAdapter;providerRoot=$providerRoot;providerFingerprintSha256=Text-Sha $providerFingerprint;capturedExecuted=[string]$capture.executed}
        v4=[ordered]@{status=[string]$v4.status;exitCategory=[string]$v4.exitCategory;findings=@($v4.findings);coverage=@($v4.coverage);rawOutputSha256=Text-Sha ([string]$capture.output)}
    })
}

[void][IO.Directory]::CreateDirectory($output)
[void][IO.Directory]::CreateDirectory($build)
[void][IO.Directory]::CreateDirectory($runtime)
Write-Json (Join-Path $output 'corpus-manifest.json') ([ordered]@{formatVersion=1;status='pass';sourceCommit=$expected.targetCommit;sourceManifestSha256=$expected.caseManifest;cases=@($corpus.ToArray())})

$logs = Join-Path $runtime 'logs'
$gaps = [Collections.Generic.List[object]]::new()
$v4CaseRuns = [Collections.Generic.List[object]]::new()
$v4ById = @{}
foreach ($case in @($corpus.ToArray())) {
    $selection = @($profileDocument.moduleSelections | Where-Object { [string]$_.id -ceq [string]$case.moduleId })
    if ($selection.Count -ne 1) { Fail "Profile module selection drift: $($case.moduleId)." }
    $safe = ([string]$case.id) -replace '[^A-Za-z0-9._-]','_'
    $caseState = Join-Path $runtime "v4-cases/$safe/state"
    $caseEvidence = Join-Path $runtime "v4-cases/$safe/evidence"
    $config = $selection[0].config | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $suiteLocal = [string]$case.replay.mode -ceq 'suite-local-provider'
    if ($suiteLocal) {
        $localPolicy = Join-Path ([string]$case.replay.providerRoot) 'policy.json'
        $config.policySha256 = if ([IO.File]::Exists($localPolicy)) { Sha $localPolicy } else { '0' * 64 }
    }
    $payload = [ordered]@{
        formatVersion = 1
        stage = 'pre'
        targetRoot = [string]$case.targetRoot
        packageRoot = Join-Path $install 'package'
        stateRoot = $caseState
        evidenceRoot = $caseEvidence
        projectId = $(if($suiteLocal){'ifx-c6c4-supplemental'}else{'ifx'})
        relativeRoots = $(if($suiteLocal){@('src')}else{@('src','tests')})
        config = $config
    }
    $payloadJson = $payload | ConvertTo-Json -Depth 100 -Compress
    $adapter = Full-File ([string]$case.replay.adapterPath) "Replay adapter $($case.moduleId)"
    $process = Run-Captured "v4-$safe" 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',$adapter) $repo (Join-Path $logs "v4-cases/$safe") @{V4_STAGE_INPUT_JSON=$payloadJson}
    $stdout = Get-Content -LiteralPath (Join-Path $logs "v4-cases/$safe/stdout.txt") -Raw
    $current = $null; try { $current = $stdout | ConvertFrom-Json -AsHashtable -Depth 100 } catch {}
    $run = [ordered]@{
        id = [string]$case.id
        moduleId = [string]$case.moduleId
        inputSha256 = Text-Sha $payloadJson
        configSha256 = Text-Sha ($config | ConvertTo-Json -Depth 100 -Compress)
        replay = $case.replay
        process = $process
        certifiedResult = $case.v4
        currentResult = $current
    }
    $v4CaseRuns.Add($run); $v4ById[[string]$case.id] = $run
    if ($process.exitCode -ne 0 -or $null -eq $current) {
        $gaps.Add([ordered]@{id=[string]$case.id;category='engine-failure';detail='V4 adapter process or structured result failed.'})
        continue
    }
    $certifiedSemantic = [ordered]@{status=$case.v4.status;exitCategory=$case.v4.exitCategory;findings=@($case.v4.findings);coverage=@($case.v4.coverage)} | ConvertTo-Json -Depth 100 -Compress
    $currentSemantic = [ordered]@{status=$current.status;exitCategory=$current.exitCategory;findings=@($current.findings);coverage=@($current.coverage)} | ConvertTo-Json -Depth 100 -Compress
    if ($currentSemantic -cne $certifiedSemantic) {
        $gaps.Add([ordered]@{id=[string]$case.id;category='v4-certified-drift';detail='Current receipted V4 semantics differ from the frozen certified capture.'})
    }
}

Write-Json (Join-Path $output 'v4-case-runs.json') ([ordered]@{formatVersion=1;caseCount=$v4CaseRuns.Count;runs=@($v4CaseRuns.ToArray())})

$v3SnapshotArchive = Join-Path $runtime 'v3-clean-target.zip'
$v3CleanTarget = Join-Path $runtime 'v3-clean-target'
$v3Snapshot = Run-Captured 'v3-clean-snapshot' 'git' @('-C',$reference,'archive','--format=zip','--output',$v3SnapshotArchive,'HEAD') $reference (Join-Path $logs 'v3-clean-snapshot')
if ($v3Snapshot.exitCode -ne 0 -or -not [IO.File]::Exists($v3SnapshotArchive)) { Fail 'Failed to create the tracked-file V3 clean Target snapshot.' }
[IO.Compression.ZipFile]::ExtractToDirectory($v3SnapshotArchive,$v3CleanTarget)
$v3CleanBefore = Text-Sha (Fingerprint $v3CleanTarget)
$v3RealReport = Join-Path $runtime 'v3-real-clean.json'
$v3Runner = Full-File (Join-Path $reference 'docs/guards/V3_ifx/commands/Invoke-IFXArchitecture.ps1') 'V3 architecture runner'
$v3Build = Run-Captured 'v3-real-clean' 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',$v3Runner,'-Mode','Scan','-TargetRoot',$v3CleanTarget,'-ReportPath',$v3RealReport,'-SkipAuthorityCheck') $v3CleanTarget (Join-Path $logs 'v3-real-clean') @{GUARD_BUILD_ROOT=$build}
if ($v3Build.exitCode -ne 0 -or -not [IO.File]::Exists($v3RealReport)) { $gaps.Add([ordered]@{id='real-clean/v3';category='engine-failure';detail='V3 real clean scan did not pass.'}) }

$hostDll = Full-File (Join-Path $install 'host/v4-guards.dll') 'Installed V4 Host'
$v4State = Join-Path $runtime 'v4-state'; $v4Evidence = Join-Path $runtime 'v4-evidence'
[void][IO.Directory]::CreateDirectory($v4State); [void][IO.Directory]::CreateDirectory($v4Evidence)
$v4Runs = [Collections.Generic.List[object]]::new()
foreach ($realCase in @([ordered]@{id='clean';root=$reference;expect=0},[ordered]@{id='violation';root=$violation;expect=16})) {
    $run = Run-Captured "v4-real-$($realCase.id)" 'dotnet' @($hostDll,'stage','run','--stage','pre','--package-root',(Join-Path $install 'package'),'--target-root',$realCase.root,'--state-root',$v4State,'--evidence-root',$v4Evidence,'--profile','ifx_profile') $repo (Join-Path $logs "v4-real-$($realCase.id)")
    $stdout = Get-Content -LiteralPath (Join-Path $logs "v4-real-$($realCase.id)/stdout.txt") -Raw
    $stderr = Get-Content -LiteralPath (Join-Path $logs "v4-real-$($realCase.id)/stderr.txt") -Raw
    $document = $null; $resultChannel = $null
    foreach ($candidate in @([ordered]@{name='stdout';text=$stdout},[ordered]@{name='stderr';text=$stderr})) {
        if ([string]::IsNullOrWhiteSpace([string]$candidate.text)) { continue }
        try { $document = [string]$candidate.text | ConvertFrom-Json -AsHashtable -Depth 100; $resultChannel = $candidate.name; break } catch {}
    }
    $v4Runs.Add([ordered]@{id=$realCase.id;process=$run;resultChannel=$resultChannel;result=$document})
    if ($run.exitCode -ne $realCase.expect -or $null -eq $document) { $gaps.Add([ordered]@{id="real-$($realCase.id)/v4";category='engine-failure';detail="V4 real $($realCase.id) exit/result mismatch."}) }
}

$v3Host = Join-Path $build 'v3-ifx/architecture-conformance/bin/LayerGuard.Ifx/debug/layerguard-ifx.dll'
$ownedRuleMap = @{}
foreach ($moduleId in $modules) {
    $ownedRuleMap[$moduleId] = @($corpus.ToArray() | Where-Object { [string]$_.moduleId -ceq $moduleId -and [string]$_.kind -ceq 'violation' } | ForEach-Object { [string]$_.ruleId } | Sort-Object -Unique)
}
$engineCases = [Collections.Generic.List[object]]::new()
if (-not [IO.File]::Exists($v3Host)) {
    $gaps.Add([ordered]@{id='v3-host';category='engine-failure';detail='Built V3 host is missing.'})
    foreach ($case in @($corpus.ToArray())) {
        $engineCases.Add([ordered]@{id=$case.id;kind=$case.kind;moduleId=$case.moduleId;claimIds=$case.claimIds;expectedRule=$case.ruleId;ownedRules=$ownedRuleMap[[string]$case.moduleId];v4=$v4ById[[string]$case.id];v3=[ordered]@{process=[ordered]@{exitCode=127};reportPath=$null;reportSha256=$null;result=$null;rules=@();violationCount=0}})
    }
} else {
    foreach ($case in @($corpus.ToArray())) {
        $safe = ([string]$case.id) -replace '[^A-Za-z0-9._-]','_'
        $report = Join-Path $runtime "v3-cases/$safe.json"
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
        $scan = Run-Captured "v3-$safe" 'dotnet' @($v3Host,'check',(Join-Path $case.targetRoot 'src'),'--config',$v3PolicyPath,'--baseline',$v3BaselinePath,'--format','json','--report',$report,'--quiet') $reference (Join-Path $logs "v3-cases/$safe")
        $v3 = $null; if ([IO.File]::Exists($report)) { $v3 = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
        $v3Rules = @(); if ($null -ne $v3) { $v3Rules = @($v3.violations | ForEach-Object { [string]$_.rule } | Sort-Object -Unique) }
        $engineCases.Add([ordered]@{id=$case.id;kind=$case.kind;moduleId=$case.moduleId;claimIds=$case.claimIds;expectedRule=$case.ruleId;ownedRules=$ownedRuleMap[[string]$case.moduleId];v4=$v4ById[[string]$case.id];v3=[ordered]@{process=$scan;reportPath=$(if($null-ne$v3){$report}else{$null});reportSha256=$(if($null-ne$v3){Sha $report}else{$null});result=$v3;rules=$v3Rules;violationCount=$(if($null-ne$v3){@($v3.violations).Count}else{0})}})
    }
}

$engineResultsPath = Join-Path $output 'engine-results.json'
$matrixPath = Join-Path $output 'parity-matrix.json'
Write-Json $engineResultsPath ([ordered]@{formatVersion=1;caseCount=$engineCases.Count;cases=@($engineCases.ToArray())})
$comparer = Full-File (Join-Path $PSScriptRoot 'Compare-IFXP102Parity.ps1') 'Independent P10.2 comparer'
$comparisonProcess = Run-Captured 'independent-parity-compare' 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',$comparer,'-InputPath',$engineResultsPath,'-OutputPath',$matrixPath) $repo (Join-Path $logs 'independent-parity-compare')
if (-not [IO.File]::Exists($matrixPath)) { Fail 'Independent comparer did not produce its matrix.' }
$matrixDocument = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ($comparisonProcess.exitCode -notin @(0,1) -or [int]$matrixDocument.caseCount -ne 52) { Fail 'Independent comparer process failed structurally.' }
foreach ($gap in @($matrixDocument.gaps)) { $gaps.Add($gap) }

$v3Post = Root-Inventory $reference @('docs/guards/V3','docs/guards/V3_ifx')
if ($v3Post.inventorySha256 -cne $v3Pre.inventorySha256) { $gaps.Add([ordered]@{id='v3-authority';category='input-mutation';detail='V3/V3_ifx authority inventory changed.'}) }
foreach ($entry in $targetBefore.GetEnumerator()) {
    $after = Text-Sha (Fingerprint ([string]$entry.Key))
    if ($after -cne [string]$entry.Value) { $gaps.Add([ordered]@{id=[string]$entry.Key;category='input-mutation';detail='Corpus Target changed.'}) }
}
foreach ($entry in $providerBefore.GetEnumerator()) {
    $after = Text-Sha (Fingerprint ([string]$entry.Key))
    if ($after -cne [string]$entry.Value) { $gaps.Add([ordered]@{id=[string]$entry.Key;category='input-mutation';detail='Suite-local provider changed.'}) }
}
$immutablePost = [ordered]@{
    reference = Text-Sha (Fingerprint $reference)
    install = Text-Sha (Fingerprint $install)
    bundle = Text-Sha (Fingerprint $bundle)
    c6cWindows = Text-Sha (Fingerprint $windows)
}
foreach ($name in @('reference','install','bundle','c6cWindows')) {
    if ([string]$immutablePost[$name] -cne [string]$immutablePre[$name]) { $gaps.Add([ordered]@{id=$name;category='input-mutation';detail="$name inventory changed."}) }
}

$status = if ($gaps.Count -eq 0) { 'pass' } else { 'fail' }
$decisionName = if ($status -ceq 'pass') { 'p10-2-parity-accepted' } else { 'p10-2-stopped-on-parity-gaps' }
Write-Json (Join-Path $output 'v4-real-runs.json') ([ordered]@{formatVersion=1;runs=@($v4Runs.ToArray())})
Write-Json (Join-Path $output 'summary.json') ([ordered]@{formatVersion=1;status=$status;decision=$decisionName;targetCommit=$expected.targetCommit;identities=$expected;toolchain=$toolchain;compositionProof=$compositionProof;corpus=[ordered]@{caseCount=$cases.Count;clean=$kindCounts.clean;missing=$kindCounts.missing;zero=$kindCounts.zero;violation=$kindCounts.violation;suiteLocalProviderCount=$providerBefore.Count;manifestSha256=Sha (Join-Path $output 'corpus-manifest.json')};v3=[ordered]@{pre=$v3Pre;post=$v3Post;cleanTargetSnapshot=[ordered]@{process=$v3Snapshot;trackedTreeBeforeRunSha256=$v3CleanBefore};realClean=$v3Build};v4=[ordered]@{caseRuns=$v4CaseRuns.Count;caseRunsSha256=Sha (Join-Path $output 'v4-case-runs.json');realRuns=@($v4Runs.ToArray())};comparison=[ordered]@{process=$comparisonProcess;caseCount=[int]$matrixDocument.caseCount;comparerGapCount=[int]$matrixDocument.gapCount;strengtheningCount=[int]$matrixDocument.strengtheningCount;totalGapCount=$gaps.Count;sha256=Sha $matrixPath};immutableRoots=[ordered]@{pre=$immutablePre;post=$immutablePost};boundary=[ordered]@{p10_2Executed=$true;p10_2Accepted=($status-ceq'pass');p10_3Started=$false;activated=$false;published=$false;v3Retired=$false;ifxCutover=$false}})
Write-Json (Join-Path $output 'p10-2-decision.json') ([ordered]@{formatVersion=1;status=$status;decision=$decisionName;summarySha256=Sha (Join-Path $output 'summary.json');corpusManifestSha256=Sha (Join-Path $output 'corpus-manifest.json');parityMatrixSha256=Sha (Join-Path $output 'parity-matrix.json');gapCount=$gaps.Count;gaps=@($gaps.ToArray());strengtheningCount=[int]$matrixDocument.strengtheningCount;strengthenings=@($matrixDocument.strengthenings);boundary=[ordered]@{p10_2ExecutionClosed=$true;p10_3Started=$false;activated=$false;published=$false;v3Retired=$false;ifxCutover=$false};recommendation=$(if($status-ceq'pass'){'P10.2 entry criteria are met; P10.3 still requires a separate Plan and authorization.'}else{'Do not enter P10.3. Review the preserved parity gaps and authorize a separate repair Plan if correction is desired.'})})

Write-Output "P10.2 ${status}: $decisionName; gaps=$($gaps.Count); strengthenings=$([int]$matrixDocument.strengtheningCount); evidence=$output"
if ($status -cne 'pass') { exit 1 }
