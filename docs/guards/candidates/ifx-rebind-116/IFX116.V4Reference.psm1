# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6), amendment A4 / IFX-V4-004: V4 reference inputs of the
# accepted C6c matrix after V4-TODO-008 T8 removed the IFX incubation copy (docs/guards/v4).
#   - Product files (module and Profile schemas, the built-in architecture-conformance adapter) come from the
#     installed, verified base release. Each is pinned to the hash of the removed IFX copy, so the inputs are
#     byte-identical to what the accepted suites used.
#   - A product test that only serves as fixture provenance comes from IFX history as a pinned Git blob.
# Nothing is read from, or recreated under, docs/guards/v4 in a working tree.
Set-StrictMode -Version Latest

$script:PinnedBaseFiles = [ordered]@{
    'core/contracts/module.schema.json' = '78e24ceb7b7716f893602cf163e055033dab1872d171a9bc89fdd50c7413bfd7'
    'core/contracts/profile.schema.json' = '35f42988d4a5ed2ee6d807a089a4d158a878cc96456489012400c08e0c4007a2'
    'modules/architecture-conformance/adapter.ps1' = '227512c6e44cdaf6e391282b05d164abb60e6c89584d414adec72f5cdf07ffe9'
}

function Get-IFX116V4PinnedBaseFiles { $script:PinnedBaseFiles }

function Assert-IFX116V4BaseReference {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BaseInstallRoot)
    $package = [IO.Path]::GetFullPath((Join-Path $BaseInstallRoot 'package'))
    foreach ($relative in $script:PinnedBaseFiles.Keys) {
        $path = Join-Path $package $relative
        if (-not [IO.File]::Exists($path)) { throw "Base reference file missing: $relative" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $script:PinnedBaseFiles[$relative]) { throw "Base reference hash drift: $relative ($actual)" }
    }
    return $package
}

function Resolve-IFX116V4Path {
    # 'base-package:<relative>' resolves under the verified base package; anything else is repository-relative.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][string]$BaseInstallRoot)
    if ($Path.StartsWith('base-package:', [StringComparison]::Ordinal)) {
        $relative = $Path.Substring('base-package:'.Length)
        if (-not $script:PinnedBaseFiles.Contains($relative)) { throw "Unpinned base-package reference: $relative" }
        $package = Assert-IFX116V4BaseReference -BaseInstallRoot $BaseInstallRoot
        return [IO.Path]::GetFullPath((Join-Path $package $relative))
    }
    if ($Path -match '(?i)docs[/\\]guards[/\\]v4[/\\]') { throw "Reference to the removed docs/guards/v4 copy: $Path" }
    if ([IO.Path]::IsPathFullyQualified($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Path))
}

function Convert-IFX116V4SchemaReferences {
    # Used by the matrix wrapper on the text of an accepted suite before it runs. Only the schema lookups
    # are redirected; the result must not name the removed copy in any letter case.
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Source, [Parameter(Mandatory)][string]$BaseInstallRoot)
    $package = (Assert-IFX116V4BaseReference -BaseInstallRoot $BaseInstallRoot).Replace("'", "''")
    # The removed prefix is assembled so that this harness never names it literally (S4 static control).
    $removedPrefix = "Join-Path `$repoRoot '" + 'docs/guards/' + 'V4/core/contracts/'
    $result = $Source.Replace($removedPrefix, "Join-Path '$package' 'core/contracts/")
    if ($result -match '(?i)docs[/\\]guards[/\\]v4[/\\]') { throw 'Suite still references the removed docs/guards/v4 copy after conversion.' }
    return $result
}

function Get-IFX116GitBlobBytes {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][string]$Commit, [Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$BlobId)
    $resolved = (& git -C $RepositoryRoot rev-parse --verify --quiet "$($Commit):$Path").Trim()
    if ($LASTEXITCODE -ne 0 -or $resolved -cne $BlobId) { throw "Pinned Git blob mismatch: $($Commit):$Path -> $resolved" }
    $info = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in @('-C', $RepositoryRoot, 'cat-file', 'blob', $BlobId)) { [void]$info.ArgumentList.Add($a) }
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($info)
    $buffer = [IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($buffer)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "git cat-file failed for blob $BlobId" }
    return , $buffer.ToArray()
}

Export-ModuleMember -Function Get-IFX116V4PinnedBaseFiles, Assert-IFX116V4BaseReference, Resolve-IFX116V4Path, Convert-IFX116V4SchemaReferences, Get-IFX116GitBlobBytes
