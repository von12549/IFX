# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: negative controls of the 0.5.0-a
# C6c harness successors; successor of candidates/ifx-rebind-116/Test-IFX116HarnessControls.ps1 (unchanged). Kept:
# the removed-path scan, the IFX-V4-004 base-reference controls, the IFX-V4-003 installer controls and the IFX-V4-002
# storage controls in the pinned Linux image. New:
# - the matrix contract and fixture specification are re-derived, and a drifted contract or catalog is rejected;
# - a production snapshot is rejected when a file drifts or the Target is at another commit;
# - PR-gate cases: synthetic PR commits on clean clones of HEAD, with the producers re-run at each commit and the
#   evidence staged as the workflow stages it, then installed-Host Post on the composed candidate. A benign src edit
#   passes; a rule-breaking edit blocks with the expected rule; a governance edit fails closed; evidence produced for
#   another commit is rejected.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'D:/IFX-Root/guard-runtime/downloads/v4-guards-1.1.6/v4-guards-1.1.6.zip',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$LinuxImage = 'ifx-c6c-sdk:10.0.303',
    [string]$LinuxImageDigest = 'sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773',
    [switch]$SkipPrGate
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.ReleaseInstaller.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.V4Reference.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Production.psm1') -Force
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim()
$trackedBefore = @(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and -not $trackedBefore) 'Harness controls require a clean tracked repository.'
$root = [IO.Path]::GetFullPath($EvidenceRoot)
if (Test-Path -LiteralPath $root) { throw "EvidenceRoot must be absent: $root" }
[void][IO.Directory]::CreateDirectory($root)
$work = Join-Path ([IO.Path]::GetTempPath()) "ifx-050-harness-controls-$([guid]::NewGuid().ToString('N'))"; [void][IO.Directory]::CreateDirectory($work)
$cases = [Collections.Generic.List[object]]::new()
function Case([string]$Id, [bool]$ExpectReject, [scriptblock]$Body) {
    $message = $null; $rejected = $false; $detail = $null
    try { $detail = & $Body } catch { $rejected = $true; $message = $_.Exception.Message }
    $cases.Add([ordered]@{ id = $Id; expected = $(if ($ExpectReject) { 'reject' } else { 'accept' }); actual = $(if ($rejected) { 'reject' } else { 'accept' }); message = $message; detail = $detail; pass = ($rejected -eq $ExpectReject) })
}
function Clone-Head([string]$Name) { $t = Join-Path $work $Name; $o = @(& git clone --no-local --quiet $repo $t 2>&1); Assert ($LASTEXITCODE -eq 0) "Clone failed ($Name): $($o -join ' ')"; $t }

# Removed incubation path (IFX-V4-003/004): no 0.5.0-a harness file names docs/guards/v4 in any letter case.
$oldPattern = '(?i)docs[/\\]guards[/\\]v4[/\\]'
Case 'no-harness-file-uses-docs-guards-v4' $false {
    $hits = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Recurse | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match $oldPattern } | ForEach-Object { [IO.Path]::GetRelativePath($PSScriptRoot, $_.FullName) })
    if ($hits.Count -ne 0) { throw "Harness files reference the removed path: $($hits -join ', ')" }
    if ((Get-Content -LiteralPath (Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1') -Raw) -notmatch $oldPattern) { throw 'Non-vacuity: the accepted c6c1 script no longer shows the old path.' }
    [ordered]@{ scannedFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Recurse).Count }
}
# IFX-V4-004: V4 reference inputs from the verified base release.
Case 'a4-base-reference-verified' $false { [ordered]@{ package = (Assert-IFX116V4BaseReference -BaseInstallRoot $BaseInstallRoot) } }
Case 'a4-base-reference-drift-rejected' $true {
    $fake = Join-Path $work 'a4-drift/base'
    foreach ($rel in (Get-IFX116V4PinnedBaseFiles).Keys) { $dst = Join-Path $fake "package/$rel"; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dst)); Copy-Item -LiteralPath (Join-Path $BaseInstallRoot "package/$rel") -Destination $dst }
    [IO.File]::AppendAllText((Join-Path $fake 'package/modules/architecture-conformance/adapter.ps1'), "`n# drift")
    Assert-IFX116V4BaseReference -BaseInstallRoot $fake
}

# Matrix contract and fixture specification.
$verifier = Join-Path $PSScriptRoot 'Test-IFX050MatrixContract.ps1'
function Verify([string]$Dir, [string]$Contract, [string]$Spec) {
    $a = @('-RepositoryRoot', $repo, '-BaseInstallRoot', $BaseInstallRoot, '-InventoryPath', $InventoryPath, '-ReportPath', (Join-Path $Dir 'summary.json'))
    if ($Contract) { $a += @('-ContractPath', $Contract) }; if ($Spec) { $a += @('-FixtureSpecPath', $Spec) }
    $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier @a 2>&1); if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
}
Case 'matrix-contract-verifier-pass' $false { Verify (Join-Path $root 'verifier') $null $null; [ordered]@{ report = 'verifier/summary.json' } }
Case 'matrix-contract-drift-rejected' $true {
    $dir = Join-Path $work 'contract-drift'; [void][IO.Directory]::CreateDirectory($dir)
    $c = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'matrix-contract-050.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $m = @($c.modules | Where-Object { $_.zeroStrategy -ceq 'fixed-checklist-zero' })[0]; $m.zeroStrategy = 'integrity-zero'; $m.zeroExitCategory = 'integrity-failure'
    Write-IFX050Json (Join-Path $dir 'contract.json') $c; Verify $dir (Join-Path $dir 'contract.json') $null
}
Case 'fixture-spec-drift-rejected' $true {
    $dir = Join-Path $work 'spec-drift'; [void][IO.Directory]::CreateDirectory($dir)
    $s = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture-spec-050.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $s.cases = @($s.cases | Select-Object -Skip 1)
    Write-IFX050Json (Join-Path $dir 'spec.json') $s; Verify $dir $null (Join-Path $dir 'spec.json')
}

# IFX-V4-003: the installer comes only from the hash-verified release archive.
Case 'installer-from-verified-archive' $false {
    $r = Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'good/work') -TargetRoot (Join-Path $root 'good/target')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($BaseArchivePath)
    try { $entry = $zip.GetEntry('v4-guards-1.1.6/package/core/distribution/Install-V4Distribution.ps1'); $stream = $entry.Open(); try { $entrySha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant() } finally { $stream.Dispose() } } finally { $zip.Dispose() }
    if ($r.installerSha256 -cne $entrySha) { throw 'Extracted installer differs from the archive entry.' }
    [ordered]@{ installerSha256 = $r.installerSha256; extractedEntries = $r.extractedEntries }
}
Case 'archive-hash-drift-rejected' $true {
    $tampered = Join-Path $root 'tampered/v4-guards-1.1.6.zip'; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $tampered)); Copy-Item -LiteralPath $BaseArchivePath -Destination $tampered; [IO.File]::AppendAllText($tampered, 'x')
    Get-IFX116ReleaseInstaller -ArchivePath $tampered -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'tampered/work') -TargetRoot (Join-Path $root 'tampered/target')
}
Case 'extraction-under-target-rejected' $true { Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'undertarget/target/work') -TargetRoot (Join-Path $root 'undertarget/target') }
Case 'wrong-version-rejected' $true { Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.5' -WorkRoot (Join-Path $root 'wrongversion/work') -TargetRoot (Join-Path $root 'wrongversion/target') }

# PR-gate cases on the composed candidate.
$prCases = [Collections.Generic.List[object]]::new()
if (-not $SkipPrGate) {
    $bundle = [IO.Path]::GetFullPath($BundleRoot); $composed = Join-Path $work 'composed'; $receipt = Join-Path $work 'composition.receipt.json'
    foreach ($d in @('compose-state', 'compose-evidence')) { [void][IO.Directory]::CreateDirectory((Join-Path $work $d)) }
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath (Join-Path $repo 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip') -BundleRoot $bundle -ReviewRecordPath $ReviewRecordPath -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $repo -StateRoot (Join-Path $work 'compose-state') -EvidenceRoot (Join-Path $work 'compose-evidence') -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Candidate composition failed: $($o -join ' ')"
    $producers = Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1'
    function New-PrCommit([string]$Name, [scriptblock]$Edit) {
        $t = Clone-Head $Name; & $Edit $t
        $o = @(& git -C $t -c user.name=IFXPrGate -c user.email=ifx-pr-gate@example.invalid commit -qam "synthetic PR: $Name" 2>&1); Assert ($LASTEXITCODE -eq 0) "Synthetic PR commit failed ($Name): $($o -join ' ')"
        $t
    }
    function Produce([string]$Target, [string]$Name) { $rec = Join-Path $root "pr-gate/$Name/production.json"; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $rec)); $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $producers -Phase Produce -TargetRoot $Target -RunRecordPath $rec 2>&1); Assert ($LASTEXITCODE -eq 0) "Producers failed ($Name): $($o | Select-Object -Last 5)"; $rec }
    function Post([string]$Target, [string]$Record, [string]$Name) {
        $ev = Join-Path $work "pr-evidence-$Name"; $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $producers -Phase Stage -TargetRoot $Target -RunRecordPath $Record -EvidenceRoot $ev 2>&1); Assert ($LASTEXITCODE -eq 0) "Staging failed ($Name): $($o -join ' ')"
        $state = Join-Path $work "pr-state-$Name"; [void][IO.Directory]::CreateDirectory($state)
        $raw = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $Target --state-root $state --evidence-root $ev --profile ifx_profile 2>&1) -join "`n"; $exit = $LASTEXITCODE
        $result = $raw | ConvertFrom-Json -Depth 100
        [IO.File]::WriteAllText((Join-Path $root "pr-gate/$Name/post.json"), $raw + "`n", [Text.UTF8Encoding]::new($false))
        [pscustomobject]@{ exit = $exit; result = $result }
    }
    function PrCase([string]$Id, [string]$Target, [string]$Record, [string]$Status, [string]$Category, [string]$Rule) {
        $r = Post $Target $Record $Id; $rules = @($r.result.findings | ForEach-Object ruleId | Sort-Object -Unique)
        $ok = $r.result.status -ceq $Status -and $r.result.exitCategory -ceq $Category -and (($Status -ceq 'pass') -eq ($r.exit -eq 0)) -and (-not $Rule -or $rules -ccontains $Rule)
        if ($Status -ceq 'pass') { $ok = $ok -and @($r.result.findings).Count -eq 0 -and @($r.result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0 }
        $prCases.Add([ordered]@{ id = $Id; commit = (& git -C $Target rev-parse HEAD).Trim(); production = [IO.Path]::GetRelativePath($root, $Record).Replace('\', '/'); expected = "$Status/$Category$(if ($Rule) { " $Rule" })"; actual = "$($r.result.status)/$($r.result.exitCategory)"; rules = $rules; exitCode = $r.exit; pass = $ok })
    }
    # Benign src edit: a comment in a governed source file.
    $benign = New-PrCommit 'pr-benign-src' { param($t) [IO.File]::AppendAllText((Join-Path $t 'src/ApiHost/IFX.ApiHost/Program.cs'), "`n// synthetic PR: benign comment`n") }
    $benignRecord = Produce $benign 'pr-benign-src'; PrCase 'pr-benign-src' $benign $benignRecord 'pass' 'success' $null
    # Rule-breaking edit: a G04 design decision identifier drifts.
    $breaking = New-PrCommit 'pr-rule-breaking' { param($t) $f = Join-Path $t 'docs/architecture/review/gates/G04/deployment-runtime-boundary.en.md'; [IO.File]::WriteAllText($f, [IO.File]::ReadAllText($f).Replace('G04-D01', 'G04-X01'), [Text.UTF8Encoding]::new($false)) }
    # Evidence produced for another commit (the benign PR) is rejected before the PR's own production.
    PrCase 'pr-foreign-production' $breaking $benignRecord 'error' 'integrity-failure' $null
    $breakingRecord = Produce $breaking 'pr-rule-breaking'; PrCase 'pr-rule-breaking' $breaking $breakingRecord 'fail' 'findings-blocking' 'G04-DOCUMENTATION'
    # Governance edit: a file whose pin 0.5.0-a keeps changes without a new bundle.
    $governance = New-PrCommit 'pr-governance' { param($t) [IO.File]::AppendAllText((Join-Path $t 'docs/architecture/review/gates/G05/open-items-v1.json'), "`n") }
    $governanceRecord = Produce $governance 'pr-governance'; PrCase 'pr-governance' $governance $governanceRecord 'error' 'integrity-failure' $null
    # Production snapshots: a drifted file and another commit are rejected.
    Case 'snapshot-file-drift-rejected' $true {
        $s = Join-Path $work 'snapshot-drift'; $null = Export-IFX050Production -TargetRoot $benign -RunRecordPath $benignRecord -OutRoot $s
        $m = Get-Content (Join-Path $s 'manifest.json') -Raw | ConvertFrom-Json; [IO.File]::AppendAllText((Join-Path $s "tree/$($m.files[0].path)"), 'x')
        # A checkout of the same commit, so only the drifted file can reject the import.
        $t = Join-Path $work 'snapshot-drift-target'; $o = @(& git clone --no-local --quiet $benign $t 2>&1); Assert ($LASTEXITCODE -eq 0) "Clone failed: $($o -join ' ')"
        # Only the drift rejection counts; any other outcome is reported as an acceptance, which fails the case.
        $reason = $null; try { Import-IFX050Production -SnapshotRoot $s -TargetRoot $t } catch { $reason = $_.Exception.Message }
        if ($reason -match 'Snapshot file drift') { throw $reason }
        [ordered]@{ unexpected = $reason }
    }
    Case 'snapshot-other-commit-rejected' $true {
        $s = Join-Path $work 'snapshot-commit'; $null = Export-IFX050Production -TargetRoot $benign -RunRecordPath $benignRecord -OutRoot $s
        Import-IFX050Production -SnapshotRoot $s -TargetRoot (Clone-Head 'snapshot-commit-target')
    }
}

# IFX-V4-002 storage controls in the pinned Linux image (the I1 control script, unchanged).
$imageId = (& docker image inspect --format '{{.Id}}' $LinuxImage).Trim()
if ($LASTEXITCODE -ne 0 -or $imageId -cne $LinuxImageDigest) { throw "Pinned Linux image missing or drifted: $imageId" }
$linuxOut = Join-Path $root 'linux'; $unlisted = Join-Path $root 'linux-unlisted'
[void][IO.Directory]::CreateDirectory($linuxOut); [void][IO.Directory]::CreateDirectory($unlisted)
$linuxLog = @(& docker run --rm --network none `
    --mount "type=bind,source=$repo,target=/source,readonly" --mount "type=bind,source=$linuxOut,target=/out" --mount "type=bind,source=$unlisted,target=/unlisted" `
    $LinuxImage pwsh -NoLogo -NoProfile -NonInteractive -File /source/docs/guards/candidates/ifx-rebind-116/Test-IFX116NativeStorageControls.ps1 -ReportPath /out/native-storage-controls.json 2>&1)
$linuxExit = $LASTEXITCODE
[IO.File]::WriteAllLines((Join-Path $root 'linux-controls.log'), [string[]]@($linuxLog | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
$linuxReport = Join-Path $linuxOut 'native-storage-controls.json'
$linux = if (Test-Path -LiteralPath $linuxReport) { Get-Content -LiteralPath $linuxReport -Raw | ConvertFrom-Json -Depth 20 } else { $null }
$linuxPass = $linuxExit -eq 0 -and $null -ne $linux -and $linux.status -ceq 'pass'

$trackedAfter = @(& git -C $repo status --porcelain --untracked-files=no); Assert (($trackedAfter -join "`n") -ceq ($trackedBefore -join "`n")) 'Tracked repository changed during harness controls.'
$windowsPass = @($cases | Where-Object { -not $_.pass }).Count -eq 0
$prPass = $SkipPrGate -or (@($prCases | Where-Object { -not $_.pass }).Count -eq 0 -and $prCases.Count -eq 4)
$status = if ($windowsPass -and $linuxPass -and $prPass -and -not $SkipPrGate) { 'pass' } elseif ($windowsPass -and $linuxPass -and $SkipPrGate) { 'partial' } else { 'failed' }
$summary = [ordered]@{
    formatVersion = 1; kind = 'ifx-050a-harness-controls'; status = $status; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; step = 'A1-4'
    harnessCommit = $commit; linuxImageDigest = $imageId; windowsCases = @($cases.ToArray()); prGateCases = @($prCases.ToArray()); prGateSkipped = [bool]$SkipPrGate
    linux = [ordered]@{ exitCode = $linuxExit; report = $(if ($null -ne $linux) { [ordered]@{ path = 'linux/native-storage-controls.json'; sha256 = Hash $linuxReport } } else { $null }); cases = $(if ($null -ne $linux) { @($linux.cases) } else { @() }) }
}
[IO.File]::WriteAllText((Join-Path $root 'summary.json'), (($summary | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$cases | ForEach-Object { "{0,-40} expected={1,-6} actual={2,-6} pass={3}" -f $_.id, $_.expected, $_.actual, $_.pass }
$prCases | ForEach-Object { "{0,-40} expected={1} actual={2} pass={3}" -f $_.id, $_.expected, $_.actual, $_.pass }
$linuxLog | ForEach-Object { "linux: $_" }
Write-Output "IFX 0.5.0-a harness controls $status`: $(Join-Path $root 'summary.json')"
if ($status -cne 'pass') { exit 1 }
