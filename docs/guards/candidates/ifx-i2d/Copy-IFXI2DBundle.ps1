# IFX I2-D (Plan 20261001-v4-ifx-i2d-publish-trusted-inputs) step D2 (ruling RD5): copy the certified 0.5.2 bundle and
# its accepted production review byte for byte into docs/guards/v4-adoption/extensions/ifx/0.5.2 on the development
# branch, in the layout the specimen reads (bundle/bundle-manifest.json, bundle/package/**, production-extension-review.json).
# Before and after the copy every bundle file must equal its manifest entry (SHA-256 and size), the manifest and the
# review their accepted hashes, and every copy must be stored by Git without normalization (the clean filter leaves the
# blob equal to the raw bytes). -Check re-verifies the committed copy.
[CmdletBinding()]
param(
    [string]$SourceBundle = 'artifacts/guards/p10-ifx-i2b/a3-052/formal-candidate-a/8f06b1c739984178bdfc5c8b5e18d558/bundle',
    [string]$SourceReview = 'artifacts/guards/p10-ifx-i2b/a3-052/c6d-review-052/production-extension-review.json',
    [string]$Destination = 'docs/guards/v4-adoption/extensions/ifx/0.5.2',
    [string]$ExpectedManifestSha256 = 'a2f619a31c2751949058812d73fdf6a6b6142832c85e772d23a714f40304e372',
    [string]$ExpectedReviewSha256 = '38eb775a885996d0ab092dc1f4fe32e600a3fdb0997bce4a018e698eed93e24d',
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { [IO.Path]::GetFullPath((Join-Path $repo $Path)) }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Test-Bundle([string]$BundleRoot) {
    $manifest = Join-Path $BundleRoot 'bundle-manifest.json'
    Assert ((Hash $manifest) -ceq $ExpectedManifestSha256) "Manifest hash mismatch: $manifest"
    $m = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -Depth 50
    $package = Join-Path $BundleRoot 'package'
    foreach ($e in @($m.files)) {
        $p = Join-Path $package $e.path
        Assert ([IO.File]::Exists($p)) "Missing bundle file: $($e.path)"
        Assert ((Hash $p) -ceq [string]$e.sha256 -and (Get-Item -LiteralPath $p).Length -eq [long]$e.size) "Bundle file differs from its manifest entry: $($e.path)"
    }
    $count = @(Get-ChildItem -LiteralPath $package -File -Recurse -Force).Count
    Assert ($count -eq @($m.files).Count) "Undeclared bundle files: $count on disk, $(@($m.files).Count) declared"
    return @($m.files).Count
}
$destination = Full $Destination
$reviewTarget = Join-Path $destination 'production-extension-review.json'
if (-not $Check) {
    Assert (-not (Test-Path -LiteralPath $destination)) "Destination already exists: $Destination"
    $declared = Test-Bundle (Full $SourceBundle)
    Assert ((Hash (Full $SourceReview)) -ceq $ExpectedReviewSha256) 'Production review hash mismatch.'
    [void][IO.Directory]::CreateDirectory($destination)
    Copy-Item -LiteralPath (Full $SourceBundle) -Destination (Join-Path $destination 'bundle') -Recurse
    Copy-Item -LiteralPath (Full $SourceReview) -Destination $reviewTarget
}
$declared = Test-Bundle (Join-Path $destination 'bundle')
Assert ((Hash $reviewTarget) -ceq $ExpectedReviewSha256) 'Copied production review hash mismatch.'
# Git stores each file without normalization: the filtered blob equals the raw-bytes blob.
$normalized = @(foreach ($f in @(Get-ChildItem -LiteralPath $destination -File -Recurse -Force)) {
    $rel = [IO.Path]::GetRelativePath($repo, $f.FullName).Replace('\', '/')
    $filtered = (& git -C $repo hash-object "--path=$rel" -- $f.FullName).Trim(); $raw = (& git -C $repo hash-object --no-filters -- $f.FullName).Trim()
    if ($filtered -cne $raw) { $rel }
    if ($Check) { $blob = (& git -C $repo rev-parse "HEAD:$rel" 2>$null); if ($LASTEXITCODE -ne 0 -or ([string]$blob).Trim() -cne $raw) { "not-committed-or-differs: $rel" } }
})
Assert ($normalized.Count -eq 0) "Files that Git would normalize or that differ from HEAD: $($normalized -join ', ')"
[ordered]@{ formatVersion = 1; kind = 'ifx-i2d-bundle-copy'; step = 'D2'; mode = $(if ($Check) { 'check' } else { 'copy' }); destination = $Destination
    bundleFiles = $declared; manifestSha256 = $ExpectedManifestSha256; reviewSha256 = $ExpectedReviewSha256; status = 'pass' } | ConvertTo-Json -Compress
