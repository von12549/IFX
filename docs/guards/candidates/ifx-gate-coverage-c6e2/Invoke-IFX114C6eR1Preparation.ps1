[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $RepositoryRoot,
    [Parameter(Mandatory)][string] $BundleRoot,
    [Parameter(Mandatory)][string] $C6dDecisionPath,
    [Parameter(Mandatory)][string] $ReviewRecordPath,
    [Parameter(Mandatory)][string] $ReviewPacketPath,
    [Parameter(Mandatory)][string] $StoppedC6eDecisionPath,
    [Parameter(Mandatory)][string] $BaseInstallRoot,
    [Parameter(Mandatory)][string] $BaseReceiptPath,
    [Parameter(Mandatory)][string] $BaseArchivePath,
    [Parameter(Mandatory)][string] $OutputInstallRoot,
    [Parameter(Mandatory)][string] $CompositionReceiptPath,
    [Parameter(Mandatory)][string] $StateRoot,
    [Parameter(Mandatory)][string] $EvidenceRoot,
    [Parameter(Mandatory)][string] $CleanTargetRoot,
    [Parameter(Mandatory)][string] $ViolatingTargetRoot,
    [Parameter(Mandatory)][string] $EvidenceOutputRoot,
    [Parameter(Mandatory)][string] $ExpectedTargetCommit,
    [Parameter(Mandatory)][string] $ExpectedBundleManifestSha256,
    [Parameter(Mandatory)][string] $ExpectedReviewPacketSha256,
    [Parameter(Mandatory)][string] $ExpectedReviewRecordSha256,
    [Parameter(Mandatory)][string] $ExpectedC6dDecisionSha256,
    [Parameter(Mandatory)][string] $ExpectedStoppedC6eDecisionSha256,
    [Parameter(Mandatory)][string] $ExpectedBaseArchiveSha256,
    [Parameter(Mandatory)][string] $ExpectedBaseReceiptSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Message) { throw $Message }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string] $Path, $Value) {
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
function Absent-Path([string] $Path, [string] $Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if ([IO.File]::Exists($full) -or [IO.Directory]::Exists($full)) { Fail "$Label must be absent: $full" }
    $full
}
function Assert-NoLink([string] $Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Fail "Link or reparse point is not allowed: $Path" }
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function Assert-Disjoint([string] $A, [string] $B) {
    if ((Is-Under $A $B) -or (Is-Under $B $A)) { Fail "Overlapping paths: $A / $B" }
}
function String-Sha256([string] $Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([Convert]::ToHexString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Value)))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-RootInventory([string] $Root) {
    $files = [Collections.Generic.List[object]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force)) {
        Assert-NoLink $file.FullName
        $files.Add([ordered]@{ path=[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/'); size=[long]$file.Length; sha256=(Hash $file.FullName) })
    }
    $ordered = @($files | Sort-Object { [string]$_.path })
    $lines = @($ordered | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" })
    [ordered]@{ root=$Root; fileCount=$ordered.Count; inventorySha256=(String-Sha256 (($lines -join "`n") + "`n")); files=$ordered }
}
function Invoke-Git([string] $Root, [string[]] $Arguments, [string] $Label) {
    $output = @(& git -C $Root @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "$Label failed: $($output -join "`n")" }
    @($output | ForEach-Object { [string]$_ })
}
function Get-GitFacts([string] $Root) {
    $head = (Invoke-Git $Root @('rev-parse','HEAD') 'git rev-parse HEAD' | Select-Object -First 1).Trim()
    $inside = (Invoke-Git $Root @('rev-parse','--is-inside-work-tree') 'git worktree probe' | Select-Object -First 1).Trim()
    $status = @(Invoke-Git $Root @('status','--porcelain=v1','--untracked-files=all') 'git status')
    [ordered]@{ root=$Root; head=$head; insideWorkTree=($inside -ceq 'true'); detached=$null; status=$status }
}

$repo = Full-Directory $RepositoryRoot 'Repository root'
$bundle = Full-Directory $BundleRoot 'Bundle root'
$c6dFile = Full-File $C6dDecisionPath 'C6d decision'
$reviewFile = Full-File $ReviewRecordPath 'Production review'
$packetFile = Full-File $ReviewPacketPath 'Review packet'
$stoppedFile = Full-File $StoppedC6eDecisionPath 'Stopped C6e decision'
$base = Full-Directory $BaseInstallRoot 'Base installation'
$baseReceiptFile = Full-File $BaseReceiptPath 'Base receipt'
$baseArchiveFile = Full-File $BaseArchivePath 'Base archive'
$manifestFile = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$output = Absent-Path $OutputInstallRoot 'Output installation'
$receipt = Absent-Path $CompositionReceiptPath 'Composition receipt'
$state = Absent-Path $StateRoot 'StateRoot'
$evidence = Absent-Path $EvidenceRoot 'EvidenceRoot'
$clean = Absent-Path $CleanTargetRoot 'Clean worktree'
$violating = Absent-Path $ViolatingTargetRoot 'Violating worktree'
$evidenceOutput = Absent-Path $EvidenceOutputRoot 'C6e-R1 evidence output'

foreach ($path in @($repo,$bundle,$c6dFile,$reviewFile,$packetFile,$stoppedFile,$base,$baseReceiptFile,$baseArchiveFile,$manifestFile)) { Assert-NoLink $path }
foreach ($parent in @([IO.Path]::GetDirectoryName($output),[IO.Path]::GetDirectoryName($receipt),[IO.Path]::GetDirectoryName($state),
        [IO.Path]::GetDirectoryName($evidence),[IO.Path]::GetDirectoryName($clean),[IO.Path]::GetDirectoryName($violating),[IO.Path]::GetDirectoryName($evidenceOutput))) {
    if (-not [IO.Directory]::Exists($parent)) { Fail "Output parent is missing: $parent" }
    Assert-NoLink $parent
}
$roots = @($bundle,$base,$output,$state,$evidence,$clean,$violating,$evidenceOutput)
for ($left=0; $left -lt $roots.Count; $left++) { for ($right=$left+1; $right -lt $roots.Count; $right++) { Assert-Disjoint $roots[$left] $roots[$right] } }

$actualHashes = [ordered]@{
    bundleManifest=Hash $manifestFile; reviewPacket=Hash $packetFile; reviewRecord=Hash $reviewFile; c6dDecision=Hash $c6dFile
    stoppedC6eDecision=Hash $stoppedFile; baseArchive=Hash $baseArchiveFile; baseReceipt=Hash $baseReceiptFile
}
$expectedHashes = [ordered]@{
    bundleManifest=$ExpectedBundleManifestSha256; reviewPacket=$ExpectedReviewPacketSha256; reviewRecord=$ExpectedReviewRecordSha256
    c6dDecision=$ExpectedC6dDecisionSha256; stoppedC6eDecision=$ExpectedStoppedC6eDecisionSha256
    baseArchive=$ExpectedBaseArchiveSha256; baseReceipt=$ExpectedBaseReceiptSha256
}
foreach ($name in @($expectedHashes.Keys)) { if ([string]$actualHashes[$name] -cne [string]$expectedHashes[$name]) { Fail "$name SHA-256 mismatch." } }

$c6d = Read-Json $c6dFile
$review = Read-Json $reviewFile
$packet = Read-Json $packetFile
$stopped = Read-Json $stoppedFile
$manifest = Read-Json $manifestFile
if ($c6d.status -cne 'pass' -or $c6d.decision -cne 'c6d-exact-bundle-human-review-accepted' -or
    $review.scope -cne 'production' -or $review.decision -cne 'accepted' -or $review.acceptedBy.authorityId -cne 'xiaolong-feng' -or
    $packet.targetCommit -cne $ExpectedTargetCommit -or $c6d.targetCommit -cne $ExpectedTargetCommit -or
    $manifest.baseVersion -cne '1.1.4' -or $manifest.version -cne '0.4.2' -or $review.bundleManifestSha256 -cne $actualHashes.bundleManifest) {
    Fail 'Frozen C6d production identity is invalid.'
}
if ($stopped.status -cne 'fail' -or $stopped.decision -cne 'c6e-stopped-on-clean-target-prerequisite-missing' -or
    $stopped.diagnosis.category -cne 'fixture-construction-prerequisite-gap' -or -not [bool]$stopped.boundary.c6eExecutionClosed) {
    Fail 'The exact stopped C6e execution is not a valid repair dependency.'
}

$verifier = Join-Path $base 'package/core/distribution/Test-V4ComposedInstallation.ps1'
$composer = Join-Path $base 'package/core/distribution/Compose-V4Extension.ps1'
$baseText = @(& $verifier -InstallRoot $base -ReceiptPath $baseReceiptFile 2>&1)
if ($LASTEXITCODE -ne 0) { Fail "Base verification failed: $($baseText -join "`n")" }
$baseProof = ($baseText -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($baseProof.status -cne 'pass' -or $baseProof.kind -cne 'base-release' -or $baseProof.receiptSha256 -cne $actualHashes.baseReceipt) { Fail 'Base proof mismatch.' }

$null = Invoke-Git $repo @('cat-file','-e',"$ExpectedTargetCommit`^{commit}") 'certified commit probe'
[void][IO.Directory]::CreateDirectory($evidenceOutput)
$cleanLog = Join-Path $evidenceOutput 'clean-worktree-add.log'
$cleanAdd = @(& git -C $repo worktree add --detach $clean $ExpectedTargetCommit 2>&1)
$cleanExit = $LASTEXITCODE
[IO.File]::WriteAllText($cleanLog,(($cleanAdd | ForEach-Object {[string]$_}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
if ($cleanExit -ne 0) { Fail "Clean worktree creation failed: $cleanLog" }
$violatingLog = Join-Path $evidenceOutput 'violating-worktree-add.log'
$violatingAdd = @(& git -C $repo worktree add --detach $violating $ExpectedTargetCommit 2>&1)
$violatingExit = $LASTEXITCODE
[IO.File]::WriteAllText($violatingLog,(($violatingAdd | ForEach-Object {[string]$_}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
if ($violatingExit -ne 0) { Fail "Violating worktree creation failed: $violatingLog" }

$cleanFacts = Get-GitFacts $clean
$violatingFacts = Get-GitFacts $violating
$cleanFacts.detached = (@(& git -C $clean symbolic-ref -q HEAD 2>&1).Count -eq 0 -and $LASTEXITCODE -ne 0)
$violatingFacts.detached = (@(& git -C $violating symbolic-ref -q HEAD 2>&1).Count -eq 0 -and $LASTEXITCODE -ne 0)
if ($cleanFacts.head -cne $ExpectedTargetCommit -or $violatingFacts.head -cne $ExpectedTargetCommit -or
    -not $cleanFacts.insideWorkTree -or -not $violatingFacts.insideWorkTree -or -not $cleanFacts.detached -or -not $violatingFacts.detached -or
    @($cleanFacts.status).Count -ne 0 -or @($violatingFacts.status).Count -ne 0) { Fail 'New Target worktrees are not clean detached certified checkouts.' }

$violationRelative = 'src/Modules/CRM/IFX.Modules.CRM.Domain/C6eR1Fault.cs'
$violationPath = Join-Path $violating $violationRelative
[IO.File]::WriteAllText($violationPath,"using IFX.Modules.CRM.Contracts;`n`nnamespace IFX.Modules.CRM.Domain;`n`ninternal sealed class C6eR1Fault;`n",[Text.UTF8Encoding]::new($false))
$violatingFacts = Get-GitFacts $violating
if (@($violatingFacts.status).Count -ne 1 -or [string]$violatingFacts.status[0] -cne "?? $violationRelative") { Fail 'Violating worktree changed outside the single deliberate fault.' }

$preInventories = [ordered]@{ baseInstallation=Get-RootInventory $base; bundle=Get-RootInventory $bundle; cleanTarget=Get-RootInventory $clean; violatingTarget=Get-RootInventory $violating }
Write-Json (Join-Path $evidenceOutput 'pre-inventories.json') ([ordered]@{formatVersion=1;roots=$preInventories})
Write-Json (Join-Path $evidenceOutput 'pre-git-facts.json') ([ordered]@{formatVersion=1;clean=$cleanFacts;violating=$violatingFacts})

[void][IO.Directory]::CreateDirectory($state)
[void][IO.Directory]::CreateDirectory($evidence)
$composeLog = Join-Path $evidenceOutput 'compose.log'
$composeText = @(& $composer -BaseInstallRoot $base -BaseReceiptPath $baseReceiptFile -BaseArchivePath $baseArchiveFile `
    -BundleRoot $bundle -ReviewRecordPath $reviewFile -OutputInstallRoot $output -CompositionReceiptPath $receipt `
    -TargetRoot $clean -StateRoot $state -EvidenceRoot $evidence 2>&1)
$composeExit = $LASTEXITCODE
[IO.File]::WriteAllText($composeLog,(($composeText | ForEach-Object {[string]$_}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
if ($composeExit -ne 0) { Fail "Production composition failed: $composeLog" }
$verifyLog = Join-Path $evidenceOutput 'composition-verification.log'
$verifyText = @(& $verifier -InstallRoot $output -ReceiptPath $receipt -BaseReceiptPath $baseReceiptFile 2>&1)
$verifyExit = $LASTEXITCODE
[IO.File]::WriteAllText($verifyLog,(($verifyText | ForEach-Object {[string]$_}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
if ($verifyExit -ne 0) { Fail "Composition verification failed: $verifyLog" }
$compositionProof = ($verifyText -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($compositionProof.status -cne 'pass' -or $compositionProof.kind -cne 'local-extension-composition' -or
    $compositionProof.scope -cne 'production' -or $compositionProof.bundleManifestSha256 -cne $actualHashes.bundleManifest) { Fail 'Production composition proof mismatch.' }

Write-Json (Join-Path $evidenceOutput 'preparation-summary.json') ([ordered]@{
    formatVersion=1;status='pass';result='git-backed-targets-and-receipted-sibling-ready';targetCommit=$ExpectedTargetCommit
    identities=$actualHashes;baseProof=$baseProof;compositionProof=$compositionProof
    compositionReceipt=[ordered]@{path=$receipt;sha256=(Hash $receipt)}
    roots=[ordered]@{state=$state;evidence=$evidence;cleanTarget=$clean;violatingTarget=$violating;install=$output}
    gitFacts=[ordered]@{clean=$cleanFacts;violating=$violatingFacts}
    preInventoryDigests=[ordered]@{
        baseInstallation=$preInventories.baseInstallation.inventorySha256;bundle=$preInventories.bundle.inventorySha256
        cleanTarget=$preInventories.cleanTarget.inventorySha256;violatingTarget=$preInventories.violatingTarget.inventorySha256
    }
    deliberateViolation=[ordered]@{path=$violationRelative;expectedRule='IMPORT-DIRECTION';expectedModule='ifx-source-policy';expectedBlocking=$true}
    installedWebUi=[ordered]@{status='pending';cleanRun=$null;violatingRun=$null}
    boundary=[ordered]@{c6eR1PreparationComplete=$true;p10_2Started=$false;p10_3Started=$false;activated=$false}
})

Write-Output "C6e-R1 Git-backed Targets and production sibling verified; Web UI practice pending: $output"
