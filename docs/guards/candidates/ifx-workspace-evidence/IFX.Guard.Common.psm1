Set-StrictMode -Version Latest

function Get-IFXSha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-IFXTextSha256([string]$Text) {
    [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))
    ).ToLowerInvariant()
}

function Test-IFXUnderRoot([string]$Path,[string]$Root) {
    $relative = [IO.Path]::GetRelativePath($Root,$Path)
    $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)
}

function Assert-IFXNoLink([string]$Path,[string]$Root) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while (Test-IFXUnderRoot $cursor $Root) {
        if ([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)) {
            $attributes = [IO.File]::GetAttributes($cursor)
            if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Workspace evidence crosses a link: $Path"
            }
        }
        if ($cursor -ceq $Root) { break }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }
}

function Get-IFXWorkspaceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string[]]$RelativeRoots,
        [Parameter(Mandatory)][string[]]$Extensions,
        [string[]]$ExcludedDirectoryNames = @('bin','obj','node_modules','dist','coverage','.vite','.git','artifacts')
    )
    $target = [IO.Path]::GetFullPath($TargetRoot)
    $extensionSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) { [void]$extensionSet.Add($extension) }
    $excluded = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $ExcludedDirectoryNames) { [void]$excluded.Add($name) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($relativeRoot in $RelativeRoots) {
        if ([IO.Path]::IsPathRooted($relativeRoot) -or $relativeRoot -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Unsafe workspace evidence root: $relativeRoot"
        }
        $root = [IO.Path]::GetFullPath((Join-Path $target $relativeRoot))
        if (-not (Test-IFXUnderRoot $root $target) -or -not [IO.Directory]::Exists($root)) { continue }
        Assert-IFXNoLink $root $target
        $pending = [Collections.Generic.Queue[string]]::new(); $pending.Enqueue($root)
        while ($pending.Count -gt 0) {
            $current = $pending.Dequeue()
            foreach ($directory in [IO.Directory]::EnumerateDirectories($current)) {
                $name = [IO.Path]::GetFileName($directory)
                if ($excluded.Contains($name)) { continue }
                if (([IO.File]::GetAttributes($directory) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Workspace evidence crosses a linked directory: $directory"
                }
                $pending.Enqueue($directory)
            }
            foreach ($file in [IO.Directory]::EnumerateFiles($current)) {
                if (-not $extensionSet.Contains([IO.Path]::GetExtension($file))) { continue }
                if (([IO.File]::GetAttributes($file) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Workspace evidence crosses a linked file: $file"
                }
                $relative = [IO.Path]::GetRelativePath($target,$file).Replace('\','/')
                if ($seen.Add($relative)) { $paths.Add($relative) }
            }
        }
    }
    $ordered = $paths.ToArray(); [Array]::Sort($ordered,[StringComparer]::Ordinal)
    $ordered
}

Export-ModuleMember -Function Get-IFXSha256,Get-IFXTextSha256,Test-IFXUnderRoot,Assert-IFXNoLink,Get-IFXWorkspaceFiles
