# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S6 successor of
# docs/guards/candidates/ifx-rebind-115/Export-IFX115C6dReviewPacket.ps1 for
# ifx-profile-candidate 0.4.4 on V4 Guards 1.1.6. It adds the exact 0.4.3 -> 0.4.4 comparison, the
# Linux result with the IFX-V4-002/003 harness and the S3 timing record.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BundleRoot,
    [Parameter(Mandatory)][string] $C6cDecisionPath,
    [Parameter(Mandatory)][string] $C6cSummaryPath,
    [Parameter(Mandatory)][string] $OrdinalInventoryPath,
    [Parameter(Mandatory)][string] $OutputRoot,
    [Parameter(Mandatory)][string] $ExpectedTargetCommit,
    [Parameter(Mandatory)][string] $ExpectedManifestSha256,
    [Parameter(Mandatory)][string] $ExpectedBaseArchiveSha256,
    [Parameter(Mandatory)][string] $PredecessorBundleRoot,
    [Parameter(Mandatory)][string] $TimingSummaryPath,
    [string] $PredecessorManifestSha256 = '24c325acfe42723f9683b7da73a9dc61abac3e738711657841fa483ae56fdc03'
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
    $full = [IO.Path]::GetFullPath($Path)
    if (-not [IO.Directory]::Exists($full)) { Fail "$Label is missing: $full" }
    $full
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    -not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)")
}

$bundle = Full-Directory $BundleRoot 'Bundle root'
$decisionFile = Full-File $C6cDecisionPath 'C6c decision'
$summaryFile = Full-File $C6cSummaryPath 'C6c summary'
$inventoryFile = Full-File $OrdinalInventoryPath 'Ordinal inventory'
$manifestFile = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$output = [IO.Path]::GetFullPath($OutputRoot)

if ([IO.Directory]::Exists($output) -or [IO.File]::Exists($output)) { Fail "Output already exists: $output" }
foreach ($input in @($bundle, $decisionFile, $summaryFile, $inventoryFile)) {
    if (Is-Under $output $input -or Is-Under $input $output) { Fail 'Output must be disjoint from every review input.' }
}

$manifestHash = Hash $manifestFile
if ($manifestHash -cne $ExpectedManifestSha256) { Fail 'Bundle manifest identity differs from the authorized C6d input.' }
$manifest = Read-Json $manifestFile
$decision = Read-Json $decisionFile
$summary = Read-Json $summaryFile

if ([string]$manifest.baseVersion -cne '1.1.6' -or [string]$manifest.version -cne '0.4.4') { Fail 'Bundle version tuple is not 1.1.6 / 0.4.4.' }
if ([string]$decision.status -cne 'pass' -or [string]$decision.decision -cne 'phase-1-complete-stop-for-human-review') { Fail 'C6c decision is not a passing human-review handoff.' }
if ([string]$decision.targetCommit -cne $ExpectedTargetCommit -or [string]$summary.sourceCommit -cne $ExpectedTargetCommit) { Fail 'C6c target commit mismatch.' }
if ([string]$decision.candidate.manifestSha256 -cne $manifestHash -or [string]$decision.c6c.productCertification.status -cne 'pass') { Fail 'C6c decision does not bind the passing candidate.' }
if ([string]$summary.status -cne 'pass' -or [string]$summary.productCertification.status -cne 'pass') { Fail 'C6c certification summary is not passing.' }
if ([bool]$summary.portabilityAssessment.blocking -or [string]$summary.portabilityAssessment.status -cne 'pass') { Fail 'The Linux leg did not pass with the IFX-V4-002/003 harness.' }
$timingFile = Full-File $TimingSummaryPath 'S3 timing summary'
$timing = Read-Json $timingFile
if ([string]$timing.decision -cne 'D1-A' -or -not [bool]$timing.native.allPass) { Fail 'S3 timing summary does not record decision D1-A.' }
if ([string]$decision.inventory.sha256 -cne (Hash $inventoryFile)) { Fail 'Ordinal inventory identity mismatch.' }

$packageRoot = Join-Path $bundle 'package'
$declaredPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$fileInventory = [Collections.Generic.List[object]]::new()
foreach ($entry in @($manifest.files)) {
    $relative = [string]$entry.path
    if (-not $declaredPaths.Add($relative)) { Fail "Duplicate or case-colliding manifest path: $relative" }
    $candidate = [IO.Path]::GetFullPath((Join-Path $packageRoot $relative))
    if (-not (Is-Under $candidate $packageRoot)) { Fail "Manifest path escapes package root: $relative" }
    if (-not [IO.File]::Exists($candidate)) { Fail "Manifest file is missing: $relative" }
    $item = Get-Item -LiteralPath $candidate -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Fail "Bundle link is not reviewable: $relative" }
    $actualHash = Hash $candidate
    if ($actualHash -cne [string]$entry.sha256 -or $item.Length -ne [long]$entry.size) { Fail "Bundle file drift: $relative" }
    $fileInventory.Add([ordered]@{ path=$relative; size=[long]$item.Length; sha256=$actualHash })
}

$actualPackageFiles = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force | ForEach-Object {
    if (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $_.LinkTarget) { Fail "Bundle link is not reviewable: $($_.FullName)" }
    [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\','/')
})
if ($actualPackageFiles.Count -ne $fileInventory.Count) { Fail 'Actual bundle file count differs from manifest inventory.' }
foreach ($relative in $actualPackageFiles) { if (-not $declaredPaths.Contains($relative)) { Fail "Undeclared bundle file: $relative" } }

$moduleIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$ceilings = [Collections.Generic.List[object]]::new()
foreach ($module in @($manifest.modules)) {
    $id = [string]$module.id
    if (-not $moduleIds.Add($id)) { Fail "Duplicate or case-colliding module ID: $id" }
    $caps = $module.allowedCapabilities
    $ceilings.Add([ordered]@{
        moduleId = $id
        allowedCapabilities = [ordered]@{
            readRoots = @($caps.readRoots)
            writeRoots = @($caps.writeRoots)
            processes = @($caps.processes)
            network = [bool]$caps.network
            maxTimeoutSeconds = [int]$caps.maxTimeoutSeconds
        }
    })
}
if ($fileInventory.Count -ne 256 -or $ceilings.Count -ne 36 -or @($manifest.profiles).Count -ne 1) { Fail 'Frozen bundle cardinality differs from the C6d plan.' }

$predecessor = Full-Directory $PredecessorBundleRoot 'Predecessor bundle root'
$predecessorManifestFile = Full-File (Join-Path $predecessor 'bundle-manifest.json') 'Predecessor manifest'
if ((Hash $predecessorManifestFile) -cne $PredecessorManifestSha256) { Fail 'Predecessor 0.4.3 manifest identity drift.' }
$predecessorManifest = Read-Json $predecessorManifestFile
$old = @{}; foreach ($entry in @($predecessorManifest.files)) { $old[[string]$entry.path] = [string]$entry.sha256 }
$new = @{}; foreach ($entry in $fileInventory) { $new[[string]$entry.path] = [string]$entry.sha256 }
$changedPaths = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $new[$_] } | Sort-Object)
$addedPaths = @($new.Keys | Where-Object { -not $old.ContainsKey($_) } | Sort-Object)
$removedPaths = @($old.Keys | Where-Object { -not $new.ContainsKey($_) } | Sort-Object)
$expectedChanged = @('profiles/catalog/ifx_profile/authority-map.json','profiles/catalog/ifx_profile/evidence-lineage.json','profiles/catalog/ifx_profile/profile.json')
if ((($changedPaths) -join '|') -cne ($expectedChanged -join '|') -or $addedPaths.Count -ne 0 -or $removedPaths.Count -ne 0) { Fail "Unexpected 0.4.3 -> 0.4.4 difference: changed=$($changedPaths -join ',') added=$($addedPaths -join ',') removed=$($removedPaths -join ',')" }
$oldModules = (@($predecessorManifest.modules) | ConvertTo-Json -Depth 20 -Compress); $newModules = (@($manifest.modules) | ConvertTo-Json -Depth 20 -Compress)
if ($oldModules -cne $newModules) { Fail 'Module declarations or ceilings differ from 0.4.3.' }
[void][IO.Directory]::CreateDirectory($output)
$inventoryOut = Join-Path $output 'file-inventory.json'
$ceilingsOut = Join-Path $output 'module-ceilings.json'
Write-Json $inventoryOut ([ordered]@{ formatVersion=1; bundleManifestSha256=$manifestHash; fileCount=$fileInventory.Count; files=@($fileInventory) })
Write-Json $ceilingsOut ([ordered]@{ formatVersion=1; bundleManifestSha256=$manifestHash; moduleCount=$ceilings.Count; moduleCeilings=@($ceilings) })

$packet = [ordered]@{
    formatVersion = 1
    status = 'ready-for-designated-human-review'
    scope = 'c6d-exact-bundle-review'
    reviewDecision = 'pending'
    acceptedBy = $null
    targetCommit = $ExpectedTargetCommit
    baseVersion = '1.1.6'
    candidateVersion = '0.4.4'
    bundle = [ordered]@{
        id = [string]$manifest.id
        manifestPath = $manifestFile
        manifestSha256 = $manifestHash
        baseArchiveSha256 = $ExpectedBaseArchiveSha256
        profileCount = @($manifest.profiles).Count
        moduleCount = $ceilings.Count
        fileCount = $fileInventory.Count
    }
    frozenInventories = [ordered]@{
        ordinalInventory = [ordered]@{ path=$inventoryFile; sha256=(Hash $inventoryFile) }
        fileInventory = [ordered]@{ path=$inventoryOut; sha256=(Hash $inventoryOut) }
        moduleCeilings = [ordered]@{ path=$ceilingsOut; sha256=(Hash $ceilingsOut) }
    }
    predecessorComparison = [ordered]@{
        predecessorVersion = '0.4.3'
        predecessorManifestSha256 = $PredecessorManifestSha256
        changedPackageFiles = @($changedPaths | ForEach-Object { [ordered]@{ path=$_; old=$old[$_]; new=$new[$_] } })
        addedPackageFiles = @(); removedPackageFiles = @()
        moduleDeclarationsAndCeilingsIdentical = $true
        manifestDifferences = 'version 0.4.3 -> 0.4.4, baseVersion 1.1.5 -> 1.1.6, profile entry hash, changed file hashes'
    }
    certification = [ordered]@{
        decision = [ordered]@{ path=$decisionFile; sha256=(Hash $decisionFile) }
        summary = [ordered]@{ path=$summaryFile; sha256=(Hash $summaryFile) }
        windowsProductCertification = 'pass'
        controls = 'pass'
        linuxPortability = [ordered]@{
            blocking = $false
            status = [string]$summary.portabilityAssessment.status
            semanticProjection = [string]$summary.portabilityAssessment.semanticProjection
            reasonCodes = @($summary.portabilityAssessment.reasonCodes)
            harness = 'IFX-V4-003 installer from the verified release archive; IFX-V4-002 Target, work and matrix on container-native storage'
            processDiagnostics = @($summary.portabilityAssessment.diagnostics)
            predecessorLinux = '0.4.3 (T7): advisory-fail; ifx-database-evidence exceeded its 60 s timeout over the 9p bind mount (IFX-V4-002).'
        }
        linuxTiming = [ordered]@{
            summary = [ordered]@{ path=$timingFile; sha256=(Hash $timingFile) }
            decision = [string]$timing.decision
            nativeMaxSeconds = $timing.native.maxSeconds
            bindMaxSeconds = $timing.bind.maxSeconds
            declaredModuleTimeoutSeconds = $timing.declaredModuleTimeoutSeconds
        }
    }
    requiredAuthority = [ordered]@{
        authorityType = 'human-review'
        authorityId = 'xiaolong-feng'
        candidateHostVerdictAllowed = $false
    }
    decisionBoundary = [ordered]@{
        startAuthorizationIsAcceptance = $false
        syntheticReviewIsAcceptance = $false
        c6eAuthorized = $false
        instruction = 'Review the exact packet and explicitly accept or reject it. Do not compose before acceptance.'
    }
}
$packetOut = Join-Path $output 'review-packet.json'
Write-Json $packetOut $packet
Write-Json (Join-Path $output 'summary.json') ([ordered]@{
    formatVersion=1
    status='pass'
    result='ready-for-designated-human-review'
    reviewPacketPath=$packetOut
    reviewPacketSha256=(Hash $packetOut)
    fileInventorySha256=(Hash $inventoryOut)
    moduleCeilingsSha256=(Hash $ceilingsOut)
    productionReviewRecordCreated=$false
    c6eAuthorized=$false
})

Write-Output "C6d review packet ready; human decision pending: $packetOut"
