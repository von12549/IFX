# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S8: build the I1 identity file consumed by
# Invoke-IFX116P102Parity.ps1 and the P10.3 successor rehearsal. Successor of ifx-rebind-115/New-IFX115IdentityFile.ps1.
# Every value is recomputed from its record. The V3/V3_ifx inventory algorithm is first reproduced on the
# accepted T7 reference (ifx-t7-clean-043); the I1 reference must then be identical (V3 unchanged since T7).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $OutputPath,
    [string] $RepositoryRoot = 'D:/IFX-Root/IFX',
    [string] $I1Reference = 'D:/IFX-Root/guard-runtime/fixtures/ifx-i1-clean-044',
    [string] $AcceptedReference = 'D:/IFX-Root/guard-runtime/fixtures/ifx-t7-clean-043'
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
if ($accepted.inventorySha256 -cne 'c910ec9c49d86f335f465483cd62723352b757db04f3adf3de6ed45a13218003' -or $accepted.fileCount -ne 562) { Fail 'The accepted T7 V3 inventory is not reproduced; the algorithm copy is wrong.' }
$i1 = Root-Inventory $I1Reference @('docs/guards/V3','docs/guards/V3_ifx')
$old = @{}; foreach ($f in $accepted.files) { $old[$f.path] = $f.sha256 }
$new = @{}; foreach ($f in $i1.files) { $new[$f.path] = $f.sha256 }
$changed = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $new[$_] } | Sort-Object)
$added = @($new.Keys | Where-Object { -not $old.ContainsKey($_) }); $removed = @($old.Keys | Where-Object { -not $new.ContainsKey($_) })
if ($changed.Count -ne 0 -or $added.Count -ne 0 -or $removed.Count -ne 0) { Fail "Unexpected V3/V3_ifx drift: changed=$($changed -join ',') added=$($added -join ',') removed=$($removed -join ',')" }
$headI1 = (& git -C $I1Reference rev-parse HEAD).Trim()

$chain = Get-Content -Raw (Join-Path $repo 'artifacts/guards/p10-ifx-116/r3-chain.json') | ConvertFrom-Json -AsHashtable -Depth 100
$bundleRoot = Join-Path $chain['outputs']['candidateA'] 'bundle'
$s7 = Get-Content -Raw (Join-Path $repo 'artifacts/guards/p10-ifx-116/s7-044/s7-decision.json') | ConvertFrom-Json -AsHashtable -Depth 100
$composeReceipt = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6-ifx-0.4.4.compose.json'
$identity = [ordered]@{
    formatVersion = 1; planId = '20260928-v4-ifx-i1-rebind-1-1-6'
    targetCommit = $headI1
    guardReleaseCommit = '960678fd1a193d87d5c499f08e79e7ce0550d96a'
    baseArchiveSha256 = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip')
    bundleManifestSha256 = Sha (Join-Path $repo "$bundleRoot/bundle-manifest.json")
    profileSha256 = Sha (Join-Path $repo "$bundleRoot/package/profiles/catalog/ifx_profile/profile.json")
    productionReviewSha256 = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-116/c6d-review-044/production-extension-review.json')
    packageSha256 = [string]$s7['composition']['packageHash']
    compositionReceiptSha256 = Sha $composeReceipt
    # Keys consumed by Invoke-IFX116P102Parity.ps1.
    c6eDecision = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-116/s7-044/s7-decision.json')
    v3Inventory = $i1.inventorySha256
    v3Policy = Sha (Join-Path $I1Reference 'docs/guards/V3_ifx/stages/post/policy/layerguard.json')
    v3TrustedComponents = Sha (Join-Path $I1Reference 'docs/guards/V3_ifx/shared/trusted-components.json')
    package = [string]$s7['composition']['packageHash']
    receipt = Sha $composeReceipt
    bundleManifest = Sha (Join-Path $repo "$bundleRoot/bundle-manifest.json")
    profile = Sha (Join-Path $repo "$bundleRoot/package/profiles/catalog/ifx_profile/profile.json")
    caseManifest = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-116/c6c-full/windows/case-manifest.json')
    c6cSummary = Sha (Join-Path $repo 'artifacts/guards/p10-ifx-116/c6c-full/windows/summary.json')
    v3InventoryDerivation = [ordered]@{ acceptedReference = $AcceptedReference; acceptedInventorySha256 = $accepted.inventorySha256; fileCount = $i1.fileCount; changedFromAccepted = $changed; reason = 'V3/V3_ifx unchanged since T7' }
    roots = [ordered]@{
        bundle = $bundleRoot
        composedInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4'
        cleanTarget = $I1Reference
        violatingTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-i1-violating-044'
    }
    records = [ordered]@{
        c6cDecision = Rec 'artifacts/guards/p10-ifx-116/c6c-decision.json'
        windowsFull = Rec 'artifacts/guards/p10-ifx-116/c6c-full/windows/summary.json'
        s6Decision = Rec 'artifacts/guards/p10-ifx-116/c6d-review-044/c6d-decision.json'
        s7Decision = Rec 'artifacts/guards/p10-ifx-116/s7-044/s7-decision.json'
    }
}
[IO.File]::WriteAllText($OutputPath, (($identity | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "I1 identity written: $OutputPath (V3 inventory $($i1.inventorySha256), changed: $($changed -join ','))"
