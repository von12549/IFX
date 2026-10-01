# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-10: the identity file that the A3-10b
# P10.2 replay and the A3-10c P10.3 rehearsal bind (a310-identity.json, successor of candidates/ifx-i2b-051/a210-identity.json).
# Every value is derived from a file: the A3-10a composition, the accepted A3-9 review, the A3-8 C6c and the clean Target.
# The V3/V3_ifx inventory is computed the way the replay computes it, and its derivation lists every V3 file that changed
# since the 0.5.1 target (I2-C brought three such changes to main). -Records adds the A3-10 record bindings afterwards.
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'a310-identity.json'),
    [string]$PredecessorIdentityPath = 'docs/guards/candidates/ifx-i2b-051/a210-identity.json',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a3-052',
    [string]$CleanTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-a310-clean-052',
    [string]$ViolatingTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-a310-violating-052',
    [string]$ComposedInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.5.2',
    [string]$Receipt = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6-ifx-0.5.2.compose.json',
    [switch]$Records
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath (Full $Path) -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Sha([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 50).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

if ($Records) {
    $identity = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    $paths = [ordered]@{
        c6cDecision = "$EvidenceRoot/c6c-decision.json"; windowsFull = "$EvidenceRoot/c6c-full/windows/summary.json"
        c6dDecision = "$EvidenceRoot/c6d-review-052/c6d-decision.json"; c6eDecision = "$EvidenceRoot/a3-10a-decision.json"
        p10_2Decision = "$EvidenceRoot/p10-2-parity-052/p10-2-decision.json"; parityAgainst051 = "$EvidenceRoot/p10-2-parity-052/parity-against-051.json"
        hostOutcomesAgainst051 = "$EvidenceRoot/p10-2-parity-052/host-outcomes-against-051.json"; remoteSnapshot = "$EvidenceRoot/p10-3-successor-052/remote-snapshot.json" }
    $identity['records'] = [ordered]@{}; foreach ($k in $paths.Keys) { $identity['records'][$k] = [ordered]@{ path = $paths[$k]; sha256 = Sha $paths[$k] } }
    Write-Json $OutputPath $identity
    Write-Output "a310-identity.json records bound: $($paths.Count)"
    exit 0
}

$decision = Get-Content -LiteralPath (Full "$EvidenceRoot/a3-10a-decision.json") -Raw | ConvertFrom-Json -Depth 50
$c6d = Get-Content -LiteralPath (Full "$EvidenceRoot/c6d-review-052/c6d-decision.json") -Raw | ConvertFrom-Json -Depth 50
if ($decision.status -cne 'pass' -or $decision.decision -cne 'a3-10a-composition-accepted') { throw 'A3-10a composition is not accepted.' }
$target = [string]$decision.targetCommit
$bundleManifest = Full ([string]$c6d.bundle.manifestPath)
$profile = Join-Path $ComposedInstall 'package/profiles/catalog/ifx_profile/profile.json'
# V3/V3_ifx inventory of the clean Target, as Invoke-IFX050P102Parity.ps1 computes it.
$rows = foreach ($relative in 'docs/guards/V3', 'docs/guards/V3_ifx') {
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $CleanTarget $relative) -File -Recurse -Force)) {
        [ordered]@{ path = [IO.Path]::GetRelativePath($CleanTarget, $file.FullName).Replace('\', '/'); size = [long]$file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
}
$ordered = @($rows | Sort-Object { [string]$_.path })
$inventorySha = Text-Sha ((@($ordered | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" }) -join "`n") + "`n")
$predecessor = Get-Content -LiteralPath (Full $PredecessorIdentityPath) -Raw | ConvertFrom-Json -Depth 50
$changed = @(& git -C $repo diff --name-status --no-renames ([string]$predecessor.targetCommit) $target -- docs/guards/V3 docs/guards/V3_ifx | ForEach-Object { $p = ([string]$_).Split("`t"); [ordered]@{ status = $p[0]; path = $p[1] } })
$identity = [ordered]@{
    formatVersion = 1; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; step = 'A3-10'; targetCommit = $target
    guardReleaseCommit = [string]$predecessor.guardReleaseCommit; baseArchiveSha256 = [string]$predecessor.baseArchiveSha256
    bundleManifestSha256 = Sha $bundleManifest; profileSha256 = Sha $profile; productionReviewSha256 = Sha "$EvidenceRoot/c6d-review-052/production-extension-review.json"
    packageSha256 = [string]$decision.composition.packageHash; compositionReceiptSha256 = Sha $Receipt
    c6eDecision = Sha "$EvidenceRoot/a3-10a-decision.json"
    v3Inventory = $inventorySha; v3InventoryFileCount = $ordered.Count
    v3Policy = Sha (Join-Path $CleanTarget 'docs/guards/V3_ifx/stages/post/policy/layerguard.json')
    v3TrustedComponents = Sha (Join-Path $CleanTarget 'docs/guards/V3_ifx/shared/trusted-components.json')
    package = [string]$decision.composition.packageHash; receipt = Sha $Receipt; bundleManifest = Sha $bundleManifest; profile = Sha $profile
    caseManifest = Sha "$EvidenceRoot/c6c-full/windows/case-manifest.json"; c6cSummary = Sha "$EvidenceRoot/c6c-full/windows/summary.json"
    v3InventoryDerivation = [ordered]@{
        acceptedIdentity = $PredecessorIdentityPath; predecessorTargetCommit = [string]$predecessor.targetCommit; predecessorFileCount = 562; fileCount = $ordered.Count
        changedFromAccepted = @($changed)
        reason = 'I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) brought these V3 changes to main and the development branch: the v4-adoption admission decision, its registration in policy-config.json and the four-entry allowlist of Test-CutoverPreservation.ps1. The V3 policy (layerguard.json), baseline and trusted-components.json that the replay runs are unchanged.' }
    roots = [ordered]@{ composedInstall = $ComposedInstall; cleanTarget = $CleanTarget; violatingTarget = $ViolatingTarget; bundle = [IO.Path]::GetRelativePath($repo, [IO.Path]::GetDirectoryName($bundleManifest)).Replace('\', '/') }
}
if ($identity.v3Policy -cne [string]$predecessor.v3Policy -or $identity.v3TrustedComponents -cne [string]$predecessor.v3TrustedComponents) { throw 'The V3 policy or trusted components changed since 0.5.1.' }
Write-Json $OutputPath $identity
Write-Output "a310-identity.json: target $($target.Substring(0, 8)), V3 inventory $($ordered.Count) files ($(@($changed).Count) changed since 0.5.1), package $($identity.package.Substring(0, 12))"
