# V4-TODO-008 T7 (Plan 20260928-v4-todo-008-t7-ifx-consumer-rebinding) step R6: build the T7 identity file
# consumed by Invoke-IFX115P102Parity.ps1 and Test-IFX115CutoverRollback.ps1. Every value is recomputed
# from its record. The V3/V3_ifx inventory uses the exact Root-Inventory algorithm of the accepted P10.2
# runner; it is first reproduced on the accepted 1.1.4 reference, then the T7 reference may differ only in
# docs/guards/V3_ifx/shared/policy-config.json (the O5 registration fix).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $OutputPath,
    [string] $RepositoryRoot = 'D:/IFX-Root/IFX',
    [string] $T7Reference = 'D:/IFX-Root/guard-runtime/fixtures/ifx-t7-clean-043',
    [string] $AcceptedReference = 'D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-clean-042'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string] $Message) { throw $Message }
function Sha([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Sha([string] $Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([Convert]::ToHexString($algorithm.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Value)))).ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
# Verbatim from docs/guards/candidates/ifx-parity-p10-2/Invoke-IFXP102Parity.ps1, plus the file rows.
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
    [ordered]@{fileCount=$ordered.Count;inventorySha256=Text-Sha (($lines -join "`n") + "`n");files=$ordered}
}
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
function Rec([string] $Relative) { $full = Join-Path $repo $Relative; if (-not [IO.File]::Exists($full)) { Fail "Missing record: $Relative" }; [ordered]@{ path = $Relative; sha256 = Sha $full } }
if (Test-Path -LiteralPath $OutputPath) { Fail "Identity file already exists: $OutputPath" }

$accepted = Root-Inventory $AcceptedReference @('docs/guards/V3','docs/guards/V3_ifx')
if ($accepted.inventorySha256 -cne '087a85f86561294cbc36223de40a6821aaa1de458164f715e06fa2404b807102' -or $accepted.fileCount -ne 562) { Fail 'The accepted 1.1.4 V3 inventory is not reproduced; the algorithm copy is wrong.' }
$t7 = Root-Inventory $T7Reference @('docs/guards/V3','docs/guards/V3_ifx')
$old = @{}; foreach ($f in $accepted.files) { $old[$f.path] = $f.sha256 }
$new = @{}; foreach ($f in $t7.files) { $new[$f.path] = $f.sha256 }
$changed = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $new[$_] } | Sort-Object)
$added = @($new.Keys | Where-Object { -not $old.ContainsKey($_) }); $removed = @($old.Keys | Where-Object { -not $new.ContainsKey($_) })
if (($changed -join '|') -cne 'docs/guards/V3_ifx/shared/policy-config.json' -or $added.Count -ne 0 -or $removed.Count -ne 0) { Fail "Unexpected V3/V3_ifx drift: changed=$($changed -join ',') added=$($added -join ',') removed=$($removed -join ',')" }
$headT7 = (& git -C $T7Reference rev-parse HEAD).Trim()

$chain = Get-Content -Raw (Join-Path $repo 'artifacts/guards/p10-ifx-115/r3-chain.json') | ConvertFrom-Json -AsHashtable -Depth 100
$bundleRoot = Join-Path $chain['outputs']['candidateA'] 'bundle'
$r5 = Get-Content -Raw (Join-Path $repo 'artifacts/guards/p10-ifx-115/r5-043/r5-decision.json') | ConvertFrom-Json -AsHashtable -Depth 100
$composeReceipt = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.5-ifx-0.4.3.compose.json'
$identity = [ordered]@{
    formatVersion = 1; planId = '20260928-v4-todo-008-t7-ifx-consumer-rebinding'
    targetCommit = $headT7
    guardReleaseCommit = 'a02ee3c66712c1cc9c3a84676da8ce1cd1bd6286'
    baseArchiveSha256 = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-115/base-archive/v4-guards-1.1.5.zip')
    bundleManifestSha256 = Sha (Join-Path $repo "$bundleRoot/bundle-manifest.json")
    profileSha256 = Sha (Join-Path $repo "$bundleRoot/package/profiles/catalog/ifx_profile/profile.json")
    productionReviewSha256 = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-115/c6d-review-043/production-extension-review.json')
    packageSha256 = [string]$r5['composition']['packageHash']
    compositionReceiptSha256 = Sha $composeReceipt
    # Keys consumed by Invoke-IFX115P102Parity.ps1.
    c6eDecision = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-115/r5-043/r5-decision.json')
    v3Inventory = $t7.inventorySha256
    v3Policy = Sha (Join-Path $T7Reference 'docs/guards/V3_ifx/stages/post/policy/layerguard.json')
    v3TrustedComponents = Sha (Join-Path $T7Reference 'docs/guards/V3_ifx/shared/trusted-components.json')
    package = [string]$r5['composition']['packageHash']
    receipt = Sha $composeReceipt
    bundleManifest = Sha (Join-Path $repo "$bundleRoot/bundle-manifest.json")
    profile = Sha (Join-Path $repo "$bundleRoot/package/profiles/catalog/ifx_profile/profile.json")
    caseManifest = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-115/c6c-full/windows/case-manifest.json')
    c6cSummary = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-115/c6c-full/windows/summary.json')
    v3InventoryDerivation = [ordered]@{ acceptedReference = $AcceptedReference; acceptedInventorySha256 = $accepted.inventorySha256; fileCount = $t7.fileCount; changedFromAccepted = $changed; reason = 'O5 registration of the C2d G03 decision (IFX 42b666ac)' }
    roots = [ordered]@{
        bundle = $bundleRoot
        composedInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.5-ifx-0.4.3'
        cleanTarget = $T7Reference
        violatingTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-t7-violating-043'
    }
    records = [ordered]@{
        c6cDecision = Rec 'artifacts/guards/p10-ifx-115/c6c-decision.json'
        windowsFull = Rec 'artifacts/guards/p10-ifx-115/c6c-full/windows/summary.json'
        r4Decision = Rec 'artifacts/guards/p10-ifx-115/c6d-review-043/c6d-decision.json'
        r5Decision = Rec 'artifacts/guards/p10-ifx-115/r5-043/r5-decision.json'
    }
}
[IO.File]::WriteAllText($OutputPath, (($identity | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "T7 identity written: $OutputPath (V3 inventory $($t7.inventorySha256), changed: $($changed -join ','))"
