[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ArchivePath,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [Parameter(Mandatory)][string] $InstallRoot,
    [string] $SidecarPath = "$ArchivePath.sha256"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedArchive = '12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95'
$expectedSource = '5bc176f61508fd01ddceb2d4e33ee34136493a35'
$expectedPackage = '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d'
$expectedReceipt = 'c052354ff6c068d740c7b7d8893da9eefbfee929bd0e396e4458741218d4a153'
$archiveName = 'v4-guards-1.1.2.zip'
$zipRoot = 'v4-guards-1.1.2/'

function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}
function Hash-File([string] $Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Hash-Stream([IO.Stream] $Stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash($Stream)).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$archive = [IO.Path]::GetFullPath($ArchivePath)
$sidecar = [IO.Path]::GetFullPath($SidecarPath)
$receiptPathFull = [IO.Path]::GetFullPath($ReceiptPath)
$installed = [IO.Path]::GetFullPath($InstallRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
Assert ([IO.File]::Exists($archive) -and [IO.Path]::GetFileName($archive) -ceq $archiveName) 'The 1.1.2 archive is missing or misnamed.'
Assert ([IO.File]::Exists($sidecar) -and [IO.File]::Exists($receiptPathFull)) 'Sidecar or receipt is missing.'
Assert ([IO.Directory]::Exists($installed)) 'Installed base is missing.'
Assert ((Hash-File $archive) -ceq $expectedArchive) 'Archive SHA-256 is not the published 1.1.2 digest.'
Assert ((Get-Content -LiteralPath $sidecar -Raw).Trim() -ceq "$expectedArchive  $archiveName") 'Archive sidecar disagrees with the published digest.'
Assert ((Hash-File $receiptPathFull) -ceq $expectedReceipt) 'Installed receipt bytes differ from the published installation record.'
$receipt = Get-Content -LiteralPath $receiptPathFull -Raw | ConvertFrom-Json -Depth 50
Assert ($receipt.formatVersion -eq 1 -and $receipt.status -ceq 'installed' -and $receipt.version -ceq '1.1.2' -and
    $receipt.archiveSha256 -ceq $expectedArchive -and $receipt.files.Count -eq 136) 'Installed receipt identity or inventory count drift.'
Assert ([IO.Path]::GetFullPath([string]$receipt.installRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) -ceq $installed) 'Receipt installRoot differs from the verified installation.'

$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $manifestEntry = $zip.GetEntry("${zipRoot}distribution-manifest.json")
    Assert ($null -ne $manifestEntry) 'Distribution manifest is missing from the archive.'
    $manifestStream = $manifestEntry.Open()
    try {
        $reader = [IO.StreamReader]::new($manifestStream)
        try { $manifestText = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    finally { $manifestStream.Dispose() }
    $manifest = $manifestText | ConvertFrom-Json -Depth 50
    Assert ($manifest.formatVersion -eq 1 -and $manifest.id -ceq 'v4-guards' -and $manifest.version -ceq '1.1.2' -and
        $manifest.rootDirectory -ceq 'v4-guards-1.1.2' -and $manifest.source.commit -ceq $expectedSource -and
        $manifest.source.packageHash -ceq $expectedPackage) 'Distribution manifest does not identify the published 1.1.2 source and Package.'
    $manifestHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($manifestText))).ToLowerInvariant()
    Assert ($manifestHash -ceq $receipt.manifestSha256) 'Distribution manifest and receipt disagree.'
    $zipFiles = @($zip.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    Assert ($zipFiles.Count -eq 136 -and @($manifest.files).Count -eq 135) 'Distribution file inventory count drift.'
    $listed = @{}
    foreach ($item in $manifest.files) {
        $relative = [string]$item.path
        Assert ($relative -match '^(package|host|companion)/' -and -not $listed.ContainsKey($relative)) "Unsafe or duplicate manifest path: $relative"
        $listed[$relative] = $item
        $entry = $zip.GetEntry("$zipRoot$relative")
        Assert ($null -ne $entry -and $entry.Length -eq $item.size) "Archive entry is missing or resized: $relative"
        $entryStream = $entry.Open()
        try { Assert ((Hash-Stream $entryStream) -ceq $item.sha256) "Archive entry hash drift: $relative" }
        finally { $entryStream.Dispose() }
    }
    foreach ($entry in $zipFiles) {
        Assert ($entry.FullName.StartsWith($zipRoot, [StringComparison]::Ordinal) -and
            ($entry.FullName -ceq "${zipRoot}distribution-manifest.json" -or
            $listed.ContainsKey($entry.FullName.Substring($zipRoot.Length)))) "Unlisted archive entry: $($entry.FullName)"
    }
}
finally { $zip.Dispose() }

$receiptFiles = @{}
foreach ($item in $receipt.files) {
    $relative = [string]$item.path
    Assert (($listed.ContainsKey($relative) -or $relative -ceq 'distribution-manifest.json') -and
        -not $receiptFiles.ContainsKey($relative)) "Unlisted or duplicate installed path: $relative"
    $receiptFiles[$relative] = $item
    $full = [IO.Path]::GetFullPath((Join-Path $installed $relative))
    Assert ($full.StartsWith($installed + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.File]::Exists($full)) "Installed file is missing or unsafe: $relative"
    $file = Get-Item -LiteralPath $full -Force
    Assert (-not ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $file.Length -eq $item.size -and
        (Hash-File $full) -ceq $item.sha256) "Installed file inventory drift: $relative"
    if ($relative -cne 'distribution-manifest.json') {
        Assert ($item.sha256 -ceq $listed[$relative].sha256) "Archive and installed inventory disagree: $relative"
    }
}
$actualFiles = @(Get-ChildItem -LiteralPath $installed -File -Recurse -Force)
Assert ($actualFiles.Count -eq $receiptFiles.Count) 'Installed tree has unreceipted files.'
$packageCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $installed 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $installed 'package') | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $packageCheck.status -ceq 'pass' -and $packageCheck.packageHash -ceq $expectedPackage) 'Installed Package validation failed.'

[ordered]@{
    status = 'pass'
    version = '1.1.2'
    sourceCommit = $expectedSource
    archiveSha256 = $expectedArchive
    packageHash = $expectedPackage
    verifiedFiles = $receiptFiles.Count
} | ConvertTo-Json -Compress
