# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: move one evidence production
# (Invoke-IFX050EvidenceProducers.ps1 -Phase Produce) to another checkout of the same commit with the same bytes.
# The C6c produces once on a Windows clone; the certification controls and the Linux leg import a snapshot of it
# instead of producing again. A snapshot holds each producer run directory and the build outputs its locks bind (the
# assembly lock's DLLs and the type lock's source DLLs), with a manifest of their hashes. Import copies them into a
# clean checkout at the recorded commit; every copied path must be ignored by Git, so the checkout stays clean.
Set-StrictMode -Version Latest

function Get-IFX050ProductionHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Export-IFX050Production {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TargetRoot, [Parameter(Mandatory)][string]$RunRecordPath, [Parameter(Mandatory)][string]$OutRoot,
        # Also keep the exact bytes of every tracked file the production read (for a checkout on another platform,
        # whose Git checkout would write other line endings than the producing checkout).
        [switch]$IncludeTrackedTree)
    $target = [IO.Path]::GetFullPath($TargetRoot); $out = [IO.Path]::GetFullPath($OutRoot)
    if (Test-Path -LiteralPath $out) { throw "Production snapshot root must be absent: $out" }
    $record = Get-Content -LiteralPath $RunRecordPath -Raw | ConvertFrom-Json -Depth 20
    if ($record.kind -cne 'ifx-050a-evidence-production' -or $record.status -cne 'pass') { throw 'The production record did not pass.' }
    if (((& git -C $target rev-parse HEAD) | Out-String).Trim() -cne [string]$record.targetCommit) { throw 'The production record is not at the TargetRoot commit.' }
    $tree = Join-Path $out 'tree'; $relatives = [Collections.Generic.List[string]]::new()
    foreach ($run in $record.runs) {
        $lockRelative = [string]$run.lockPath; $runRelative = $lockRelative.Substring(0, $lockRelative.Length - 'evidence-lock.json'.Length).TrimEnd('/')
        $source = Join-Path $target $runRelative; if (-not [IO.Directory]::Exists($source)) { throw "Producer run directory missing: $runRelative" }
        foreach ($f in Get-ChildItem -LiteralPath $source -File -Recurse -Force) { $relatives.Add([IO.Path]::GetRelativePath($target, $f.FullName).Replace('\', '/')) }
        $lock = Get-Content -LiteralPath (Join-Path $target $lockRelative) -Raw | ConvertFrom-Json -Depth 100
        # Build outputs the consumers re-hash in the Target: assembly DLLs (path) and type source DLLs (sourcePath).
        if ($run.gate -ceq 'assembly') { foreach ($a in @($lock.assemblies)) { $relatives.Add([string]$a.path) } }
        if ($run.gate -ceq 'type') { foreach ($a in @($lock.assemblies)) { $relatives.Add([string]$a.sourcePath) } }
    }
    $files = [Collections.Generic.List[object]]::new()
    foreach ($relative in @($relatives | Sort-Object -Unique)) {
        $source = Join-Path $target $relative; if (-not [IO.File]::Exists($source)) { throw "Production file missing: $relative" }
        $dest = Join-Path $tree $relative; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)); [IO.File]::Copy($source, $dest)
        $files.Add([ordered]@{ path = $relative; sha256 = Get-IFX050ProductionHash $dest })
    }
    $sourceFiles = [Collections.Generic.List[object]]::new()
    if ($IncludeTrackedTree) {
        if (@(& git -C $target status --porcelain --untracked-files=no).Count -ne 0) { throw 'The producing checkout has tracked changes.' }
        foreach ($relative in @(& git -C $target -c core.quotePath=false ls-files)) {
            $source = Join-Path $target $relative; if (-not [IO.File]::Exists($source)) { continue }
            $dest = Join-Path $out "source/$relative"; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)); [IO.File]::Copy($source, $dest)
            $sourceFiles.Add([ordered]@{ path = $relative; sha256 = Get-IFX050ProductionHash $dest })
        }
    }
    Copy-Item -LiteralPath $RunRecordPath -Destination (Join-Path $out 'production.json')
    $manifest = [ordered]@{ formatVersion = 1; kind = 'ifx-050a-production-snapshot'; targetCommit = [string]$record.targetCommit; productionSha256 = Get-IFX050ProductionHash (Join-Path $out 'production.json'); fileCount = $files.Count; files = @($files.ToArray()); sourceFileCount = $sourceFiles.Count; sourceFiles = @($sourceFiles.ToArray()) }
    [IO.File]::WriteAllText((Join-Path $out 'manifest.json'), (($manifest | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    [ordered]@{ path = $out; fileCount = $files.Count; manifestSha256 = Get-IFX050ProductionHash (Join-Path $out 'manifest.json') }
}

function Import-IFX050Production {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SnapshotRoot, [Parameter(Mandatory)][string]$TargetRoot)
    $snapshot = [IO.Path]::GetFullPath($SnapshotRoot); $target = [IO.Path]::GetFullPath($TargetRoot)
    $manifest = Get-Content -LiteralPath (Join-Path $snapshot 'manifest.json') -Raw | ConvertFrom-Json -Depth 10
    if ($manifest.kind -cne 'ifx-050a-production-snapshot') { throw 'Not a production snapshot.' }
    if ((Get-IFX050ProductionHash (Join-Path $snapshot 'production.json')) -cne [string]$manifest.productionSha256) { throw 'Production record drift in the snapshot.' }
    if (((& git -C $target rev-parse HEAD) | Out-String).Trim() -cne [string]$manifest.targetCommit) { throw 'The snapshot is not at the TargetRoot commit.' }
    foreach ($f in $manifest.files) {
        $source = Join-Path $snapshot "tree/$($f.path)"; if ((Get-IFX050ProductionHash $source) -cne [string]$f.sha256) { throw "Snapshot file drift: $($f.path)" }
        $dest = Join-Path $target $f.path; if ([IO.File]::Exists($dest)) { throw "Production file already present in the Target: $($f.path)" }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)); [IO.File]::Copy($source, $dest)
        # The copy is newer than the checkout, as the build output was newer than its sources (the assembly consumer
        # rejects a DLL older than its project sources as stale).
        [IO.File]::SetLastWriteTimeUtc($dest, [DateTime]::UtcNow)
    }
    if (@(& git -C $target status --porcelain --untracked-files=all).Count -ne 0) { throw 'Imported production files are not ignored by Git; the Target is not clean.' }
    $record = Join-Path $snapshot 'production.json'
    [ordered]@{ productionRecord = $record; fileCount = @($manifest.files).Count; targetCommit = [string]$manifest.targetCommit }
}

function Copy-IFX050ProductionSource {
    # Writes the producing checkout's tracked bytes (Export -IncludeTrackedTree) over a checkout of the same commit.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SnapshotRoot, [Parameter(Mandatory)][string]$TargetRoot)
    $snapshot = [IO.Path]::GetFullPath($SnapshotRoot); $target = [IO.Path]::GetFullPath($TargetRoot)
    $manifest = Get-Content -LiteralPath (Join-Path $snapshot 'manifest.json') -Raw | ConvertFrom-Json -Depth 10
    if ([int]$manifest.sourceFileCount -lt 1) { throw 'The snapshot holds no tracked source bytes.' }
    if (((& git -C $target rev-parse HEAD) | Out-String).Trim() -cne [string]$manifest.targetCommit) { throw 'The snapshot is not at the TargetRoot commit.' }
    $tracked = @(& git -C $target -c core.quotePath=false ls-files | Sort-Object); $listed = @($manifest.sourceFiles | ForEach-Object path | Sort-Object)
    if (($tracked -join "`n") -cne ($listed -join "`n")) { throw 'The snapshot source list differs from the tracked files of the TargetRoot.' }
    foreach ($f in $manifest.sourceFiles) {
        $source = Join-Path $snapshot "source/$($f.path)"; if ((Get-IFX050ProductionHash $source) -cne [string]$f.sha256) { throw "Snapshot source drift: $($f.path)" }
        $dest = Join-Path $target $f.path; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)); [IO.File]::Copy($source, $dest, $true)
    }
    [ordered]@{ sourceFileCount = @($manifest.sourceFiles).Count; targetCommit = [string]$manifest.targetCommit }
}

Export-ModuleMember -Function Export-IFX050Production, Import-IFX050Production, Copy-IFX050ProductionSource
