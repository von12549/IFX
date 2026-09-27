[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $RepositoryRoot,
    [Parameter(Mandatory)][string] $BundleRoot,
    [Parameter(Mandatory)][string] $C6dDecisionPath,
    [Parameter(Mandatory)][string] $ReviewRecordPath,
    [Parameter(Mandatory)][string] $ReviewPacketPath,
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
function Assert-NoLinks([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
                Fail "Link or reparse point is not allowed: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function Assert-Disjoint([string] $A, [string] $B, [string] $Label) {
    if ((Is-Under $A $B) -or (Is-Under $B $A)) { Fail "Overlapping paths ($Label): $A / $B" }
}
function String-Sha256([string] $Value) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-RootInventory([string] $Root) {
    Assert-NoLinks $Root
    $files = [Collections.Generic.List[object]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force)) {
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $file.LinkTarget) { Fail "Inventory root contains a link: $($file.FullName)" }
        $files.Add([ordered]@{
            path = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\','/')
            size = [long]$file.Length
            sha256 = Hash $file.FullName
        })
    }
    $ordered = @($files | Sort-Object { [string]$_.path })
    $lines = @($ordered | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" })
    [ordered]@{ root=$Root; fileCount=$ordered.Count; inventorySha256=(String-Sha256 (($lines -join "`n") + "`n")); files=$ordered }
}

$repo = Full-Directory $RepositoryRoot 'Repository root'
$bundle = Full-Directory $BundleRoot 'Bundle root'
$decisionFile = Full-File $C6dDecisionPath 'C6d decision'
$reviewFile = Full-File $ReviewRecordPath 'Production review record'
$packetFile = Full-File $ReviewPacketPath 'C6d review packet'
$base = Full-Directory $BaseInstallRoot 'Base installation'
$baseReceiptFile = Full-File $BaseReceiptPath 'Base receipt'
$baseArchiveFile = Full-File $BaseArchivePath 'Base archive'
$manifestFile = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$output = Absent-Path $OutputInstallRoot 'Output installation'
$receipt = Absent-Path $CompositionReceiptPath 'Composition receipt'
$state = Absent-Path $StateRoot 'StateRoot'
$evidence = Absent-Path $EvidenceRoot 'EvidenceRoot'
$clean = Absent-Path $CleanTargetRoot 'Clean TargetRoot'
$violating = Absent-Path $ViolatingTargetRoot 'Violating TargetRoot'
$evidenceOutput = Absent-Path $EvidenceOutputRoot 'C6e evidence output'

foreach ($input in @($repo,$bundle,$decisionFile,$reviewFile,$packetFile,$base,$baseReceiptFile,$baseArchiveFile,$manifestFile)) { Assert-NoLinks $input }
foreach ($parent in @([IO.Path]::GetDirectoryName($output),[IO.Path]::GetDirectoryName($receipt),[IO.Path]::GetDirectoryName($state),
        [IO.Path]::GetDirectoryName($evidence),[IO.Path]::GetDirectoryName($clean),[IO.Path]::GetDirectoryName($violating),[IO.Path]::GetDirectoryName($evidenceOutput))) {
    if (-not [IO.Directory]::Exists($parent)) { Fail "Output parent is missing: $parent" }
    Assert-NoLinks $parent
}

$roots = @($bundle,$base,$output,$state,$evidence,$clean,$violating,$evidenceOutput)
for ($left = 0; $left -lt $roots.Count; $left++) {
    for ($right = $left + 1; $right -lt $roots.Count; $right++) { Assert-Disjoint $roots[$left] $roots[$right] 'root isolation' }
}
foreach ($externalFile in @($receipt,$baseReceiptFile,$baseArchiveFile,$reviewFile,$decisionFile,$packetFile)) {
    if (Is-Under $externalFile $output) { Fail "External authority or receipt file cannot be inside output installation: $externalFile" }
}

$actualHashes = [ordered]@{
    bundleManifest = Hash $manifestFile
    reviewPacket = Hash $packetFile
    reviewRecord = Hash $reviewFile
    c6dDecision = Hash $decisionFile
    baseArchive = Hash $baseArchiveFile
    baseReceipt = Hash $baseReceiptFile
}
$expectedHashes = [ordered]@{
    bundleManifest = $ExpectedBundleManifestSha256
    reviewPacket = $ExpectedReviewPacketSha256
    reviewRecord = $ExpectedReviewRecordSha256
    c6dDecision = $ExpectedC6dDecisionSha256
    baseArchive = $ExpectedBaseArchiveSha256
    baseReceipt = $ExpectedBaseReceiptSha256
}
foreach ($name in @($expectedHashes.Keys)) {
    if ([string]$actualHashes[$name] -cne [string]$expectedHashes[$name]) { Fail "$name SHA-256 differs from the authorized C6e input." }
}

$decision = Read-Json $decisionFile
$review = Read-Json $reviewFile
$packet = Read-Json $packetFile
$manifest = Read-Json $manifestFile
if ($decision.status -cne 'pass' -or $decision.decision -cne 'c6d-exact-bundle-human-review-accepted' -or
    -not [bool]$decision.boundary.c6dComplete -or -not [bool]$decision.boundary.productionReviewAccepted) { Fail 'C6d decision is not a passing exact-bundle human acceptance.' }
if ($decision.authority.authorityType -cne 'human-review' -or $decision.authority.authorityId -cne 'xiaolong-feng' -or
    [bool]$decision.authority.candidateHostVerdictAllowed) { Fail 'C6d authority tuple is invalid.' }
if ($review.scope -cne 'production' -or $review.decision -cne 'accepted' -or
    $review.acceptedBy.authorityType -cne 'human-review' -or $review.acceptedBy.authorityId -cne 'xiaolong-feng' -or
    [bool]$review.acceptedBy.candidateHostVerdictAllowed) { Fail 'Production review record is not the designated acceptance.' }
if ($packet.targetCommit -cne $ExpectedTargetCommit -or $decision.targetCommit -cne $ExpectedTargetCommit -or
    $decision.bundle.manifestSha256 -cne $actualHashes.bundleManifest -or $review.bundleManifestSha256 -cne $actualHashes.bundleManifest -or
    $packet.bundle.manifestSha256 -cne $actualHashes.bundleManifest -or $review.baseArchiveSha256 -cne $actualHashes.baseArchive -or
    $manifest.baseVersion -cne '1.1.4' -or $manifest.version -cne '0.4.2' -or @($manifest.files).Count -ne 256 -or
    @($manifest.modules).Count -ne 36 -or @($manifest.profiles).Count -ne 1) { Fail 'Accepted packet, bundle, base or frozen Target identity mismatch.' }

$verifier = Join-Path $base 'package/core/distribution/Test-V4ComposedInstallation.ps1'
$composer = Join-Path $base 'package/core/distribution/Compose-V4Extension.ps1'
foreach ($script in @($verifier,$composer)) { if (-not [IO.File]::Exists($script)) { Fail "Required installed distribution command is missing: $script" } }
$baseOutput = @(& $verifier -InstallRoot $base -ReceiptPath $baseReceiptFile 2>&1)
if ($LASTEXITCODE -ne 0) { Fail "Base installation verification failed: $($baseOutput -join "`n")" }
$baseProof = ($baseOutput -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($baseProof.status -cne 'pass' -or $baseProof.kind -cne 'base-release' -or $baseProof.productVersion -cne '1.1.4' -or
    $baseProof.baseArchiveSha256 -cne $actualHashes.baseArchive -or $baseProof.receiptSha256 -cne $actualHashes.baseReceipt) {
    Fail 'Verified base proof differs from the frozen 1.1.4 identity.'
}

$commitProbe = @(& git -C $repo cat-file -e "$ExpectedTargetCommit`^{commit}" 2>&1)
if ($LASTEXITCODE -ne 0) { Fail "Frozen Target commit is unavailable: $($commitProbe -join "`n")" }

[void][IO.Directory]::CreateDirectory($evidenceOutput)
$archivePath = Join-Path $evidenceOutput 'frozen-target.zip'
$archiveLog = Join-Path $evidenceOutput 'git-archive.log'
$archiveOutput = @(& git -C $repo archive '--format=zip' "--output=$archivePath" $ExpectedTargetCommit 2>&1)
$archiveExit = $LASTEXITCODE
[IO.File]::WriteAllText($archiveLog, (($archiveOutput | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
if ($archiveExit -ne 0 -or -not [IO.File]::Exists($archivePath)) { Fail "Frozen Target export failed. See $archiveLog" }
Expand-Archive -LiteralPath $archivePath -DestinationPath $clean
Expand-Archive -LiteralPath $archivePath -DestinationPath $violating

$violationPath = Join-Path $violating 'src/Modules/CRM/IFX.Modules.CRM.Domain/C6eFault.cs'
if ([IO.File]::Exists($violationPath)) { Fail "Deliberate violation path unexpectedly exists: $violationPath" }
[IO.File]::WriteAllText($violationPath, "using IFX.Modules.CRM.Contracts;`n`nnamespace IFX.Modules.CRM.Domain;`n`ninternal sealed class C6eFault;`n", [Text.UTF8Encoding]::new($false))

$preInventories = [ordered]@{
    baseInstallation = Get-RootInventory $base
    bundle = Get-RootInventory $bundle
    cleanTarget = Get-RootInventory $clean
    violatingTarget = Get-RootInventory $violating
}
Write-Json (Join-Path $evidenceOutput 'pre-inventories.json') ([ordered]@{ formatVersion=1; roots=$preInventories })

[void][IO.Directory]::CreateDirectory($state)
[void][IO.Directory]::CreateDirectory($evidence)
$composeLog = Join-Path $evidenceOutput 'compose.log'
$composeOutput = @(& $composer -BaseInstallRoot $base -BaseReceiptPath $baseReceiptFile -BaseArchivePath $baseArchiveFile `
    -BundleRoot $bundle -ReviewRecordPath $reviewFile -OutputInstallRoot $output -CompositionReceiptPath $receipt `
    -TargetRoot $clean -StateRoot $state -EvidenceRoot $evidence 2>&1)
$composeExit = $LASTEXITCODE
[IO.File]::WriteAllText($composeLog, (($composeOutput | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
if ($composeExit -ne 0) { Fail "Production composition failed. See $composeLog" }

$verifyLog = Join-Path $evidenceOutput 'composition-verification.log'
$verifyOutput = @(& $verifier -InstallRoot $output -ReceiptPath $receipt -BaseReceiptPath $baseReceiptFile 2>&1)
$verifyExit = $LASTEXITCODE
[IO.File]::WriteAllText($verifyLog, (($verifyOutput | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
if ($verifyExit -ne 0) { Fail "Composed installation verification failed. See $verifyLog" }
$compositionProof = ($verifyOutput -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($compositionProof.status -cne 'pass' -or $compositionProof.kind -cne 'local-extension-composition' -or
    $compositionProof.scope -cne 'production' -or $compositionProof.bundleManifestSha256 -cne $actualHashes.bundleManifest) {
    Fail 'Composed installation proof is not the accepted production bundle.'
}

Write-Json (Join-Path $evidenceOutput 'preparation-summary.json') ([ordered]@{
    formatVersion=1; status='pass'; result='receipted-sibling-ready-for-installed-web-ui-practice'; targetCommit=$ExpectedTargetCommit
    identities=$actualHashes; baseProof=$baseProof; compositionProof=$compositionProof
    compositionReceipt=[ordered]@{ path=$receipt; sha256=(Hash $receipt) }
    installation=[ordered]@{ path=$output; packageRoot=(Join-Path $output 'package') }
    roots=[ordered]@{ state=$state; evidence=$evidence; cleanTarget=$clean; violatingTarget=$violating }
    preInventoryDigests=[ordered]@{
        baseInstallation=$preInventories.baseInstallation.inventorySha256; bundle=$preInventories.bundle.inventorySha256
        cleanTarget=$preInventories.cleanTarget.inventorySha256; violatingTarget=$preInventories.violatingTarget.inventorySha256
    }
    deliberateViolation=[ordered]@{ path='src/Modules/CRM/IFX.Modules.CRM.Domain/C6eFault.cs'; expectedRule='IMPORT-DIRECTION'; expectedModule='ifx-source-policy'; expectedBlocking=$true }
    installedWebUi=[ordered]@{ status='pending'; cleanRun=$null; violatingRun=$null }
    boundary=[ordered]@{ c6ePreparationComplete=$true; p10_2Started=$false; p10_3Started=$false; activated=$false }
})

Write-Output "C6e production sibling verified; installed Web UI practice pending: $output"
