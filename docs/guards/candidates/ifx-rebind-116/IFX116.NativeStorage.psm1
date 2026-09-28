# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6), IFX-V4-002: the C6c Linux leg keeps its Target, work and
# report paths on container-native storage. File I/O over the Docker Desktop bind mount of the Windows
# checkout (9p) made ifx-database-evidence exceed its 60 s timeout in T7 (S3: 1.2-1.7 s native, 58-69 s bind).
Set-StrictMode -Version Latest

function Get-IFX116Device([string]$Path) {
    $probe = $Path
    while (-not (Test-Path -LiteralPath $probe)) { $probe = [IO.Path]::GetDirectoryName($probe); if ([string]::IsNullOrEmpty($probe)) { throw "No existing ancestor: $Path" } }
    $device = (& stat -c '%d' $probe).Trim(); if ($LASTEXITCODE -ne 0) { throw "stat failed: $probe" }
    $type = (& stat -f -c '%T' $probe).Trim(); if ($LASTEXITCODE -ne 0) { throw "stat -f failed: $probe" }
    [ordered]@{ probe = $probe; device = $device; fileSystem = $type }
}

function Assert-IFX116NativeStorage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Paths, [Parameter(Mandatory)][string[]]$BindRoots)
    if (-not $IsLinux) { throw 'Native-storage checks run on Linux only.' }
    $full = @($Paths | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('/') })
    $binds = @($BindRoots | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('/') })
    # Every working path shares the directory of the last path (the Linux summary report).
    $root = [IO.Path]::GetDirectoryName($full[-1])
    foreach ($p in $full) {
        if (-not ($p -ceq $root -or $p.StartsWith("$root/", [StringComparison]::Ordinal))) { throw "Linux working path outside the native root ${root}: $p" }
        foreach ($b in $binds) {
            if ($p -ceq $b -or $p.StartsWith("$b/", [StringComparison]::Ordinal) -or $b.StartsWith("$p/", [StringComparison]::Ordinal)) { throw "Linux working path must not be on the bind-mounted root ${b}: $p" }
        }
    }
    [void][IO.Directory]::CreateDirectory($root)
    $native = Get-IFX116Device $root
    if ($native.fileSystem -in @('9p', 'v9fs', 'fuseblk', 'cifs', 'smb2', 'nfs', 'drvfs')) { throw "Linux native root is on a shared file system ($($native.fileSystem)): $root" }
    foreach ($b in $binds) {
        if (-not (Test-Path -LiteralPath $b)) { continue }
        $bind = Get-IFX116Device $b
        if ($bind.device -ceq $native.device) { throw "Linux native root ${root} shares a device with the bind-mounted root $b" }
    }
    return $root
}

function Copy-IFX116NativeResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$NativeRoot, [Parameter(Mandatory)][string]$OutRoot, [string[]]$Exclude = @())
    # Runs in a finally block: it reports, and never masks the original outcome with its own failure.
    try {
        [void][IO.Directory]::CreateDirectory($OutRoot)
        $rows = [Collections.Generic.List[object]]::new()
        if (Test-Path -LiteralPath $NativeRoot) {
            foreach ($item in @(Get-ChildItem -LiteralPath $NativeRoot -Force | Sort-Object Name)) {
                if ($Exclude -ccontains $item.Name) { $rows.Add([ordered]@{ name = $item.Name; copied = $false; reason = 'excluded' }); continue }
                Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $OutRoot $item.Name) -Recurse -Force
                $files = @(if ($item.PSIsContainer) { Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force } else { $item })
                $bytes = if ($files.Count -eq 0) { [long]0 } else { [long](($files | Measure-Object Length -Sum).Sum) }
                $rows.Add([ordered]@{ name = $item.Name; copied = $true; fileCount = $files.Count; bytes = $bytes })
            }
        }
        $manifest = [ordered]@{ formatVersion = 1; kind = 'ifx-i1-linux-native-copyback'; nativeRoot = $NativeRoot; outRoot = $OutRoot; items = @($rows.ToArray()) }
        [IO.File]::WriteAllText((Join-Path $OutRoot 'native-copyback.json'), (($manifest | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    } catch {
        Write-Warning "Native result copy-back failed: $($_.Exception.Message)"
    }
}

function Sync-IFX116CheckoutIndex {
    # Amendment A5: the Linux positive runner clones with core.autocrlf=true and then overwrites every tracked
    # file with the Windows worktree bytes. Git then reports every file as modified: the copies over the 9p
    # mount carry the executable bit, and files that are LF on Windows changed size against the CRLF checkout
    # (git treats a size change as modified without comparing content). The throwaway checkout records no
    # file modes (core.filemode=false) and restages the tracked files. Identical content restages to the same
    # blobs and leaves no change; any real difference remains a staged change and is rejected here, and again
    # by the matrix's tracked-source-clean precondition.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TargetRoot)
    $before = @(& git -C $TargetRoot status --porcelain --untracked-files=no 2>&1); if ($LASTEXITCODE -ne 0) { throw 'git status failed before index sync.' }
    & git -C $TargetRoot config core.filemode false; if ($LASTEXITCODE -ne 0) { throw 'git config core.filemode failed.' }
    $null = @(& git -C $TargetRoot add -u 2>&1); if ($LASTEXITCODE -ne 0) { throw 'git add -u failed.' }
    $after = @(& git -C $TargetRoot status --porcelain --untracked-files=no 2>&1); if ($LASTEXITCODE -ne 0) { throw 'git status failed after index sync.' }
    if ($after.Count -ne 0) { throw "Native checkout content differs from the bound commit: $(@($after | Select-Object -First 10) -join '; ')" }
    [ordered]@{ reportedBeforeSync = $before.Count; remainingAfterSync = 0; fileMode = 'false' }
}

Export-ModuleMember -Function Assert-IFX116NativeStorage, Copy-IFX116NativeResults, Sync-IFX116CheckoutIndex
