# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6), IFX-V4-003: the C6c Linux leg takes the V4 installer from
# the hash-verified release archive. It never reads the Target's former docs/guards/v4 incubation copy.
Set-StrictMode -Version Latest

function Get-IFX116ReleaseInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ArchivePath,
        [Parameter(Mandatory)][string]$ExpectedArchiveSha256,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$WorkRoot,
        [Parameter(Mandatory)][string]$TargetRoot
    )
    $archive = [IO.Path]::GetFullPath($ArchivePath)
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $ExpectedArchiveSha256) { throw "Release archive hash drift: $actual" }
    $target = [IO.Path]::GetFullPath($TargetRoot).TrimEnd('/', '\')
    $destination = [IO.Path]::GetFullPath((Join-Path $WorkRoot 'release-installer'))
    $sep = [IO.Path]::DirectorySeparatorChar
    if ($destination.StartsWith($target + $sep, [StringComparison]::Ordinal) -or $destination -ceq $target) { throw 'The release installer must not be extracted under the TargetRoot.' }
    if (Test-Path -LiteralPath $destination) { throw "Release installer root must be absent: $destination" }
    # The installer needs its sibling package files (contracts, runtime), so the whole package tree of the
    # verified archive is extracted.
    $prefix = "v4-guards-$Version/package/"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    $count = 0
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if (-not $name.StartsWith($prefix, [StringComparison]::Ordinal) -or $name.EndsWith('/')) { continue }
            if ($name -match '(^|/)\.\.(/|$)') { throw "Unsafe archive entry: $name" }
            $file = [IO.Path]::GetFullPath((Join-Path $destination $name))
            if (-not $file.StartsWith($destination + $sep, [StringComparison]::Ordinal)) { throw "Archive entry escapes the installer root: $name" }
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $file)
            $count++
        }
    } finally { $zip.Dispose() }
    $installer = Join-Path $destination "v4-guards-$Version/package/core/distribution/Install-V4Distribution.ps1"
    if (-not [IO.File]::Exists($installer)) { throw 'The release archive has no package installer.' }
    if ($installer.Replace('\', '/') -match '/docs/guards/v4(/|$)') { throw 'Installer path falls back to docs/guards/v4.' }
    [ordered]@{
        source = 'release-archive'
        archiveSha256 = $actual
        installerPath = $installer
        installerSha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
        extractedEntries = $count
    }
}

Export-ModuleMember -Function Get-IFX116ReleaseInstaller
