# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step B1, IFX-V4-006: archive copy-back of the C6c
# Linux results. The I1 harness (IFX116.NativeStorage.psm1, Copy-IFX116NativeResults) copied every native result
# file to the Windows bind mount one by one; the 65,567-file matrix tree took about 90 minutes over 9p. This module
# packs the native results into one gzip tar on native storage, copies that single file plus the small reports
# the parallel runner and the review steps read, and records a listing (path, size, SHA-256) of every archived
# file. Test-IFXI2BNativeArchive re-checks the copy on either platform. The I1 module stays unchanged as the
# historical harness.
Set-StrictMode -Version Latest

function Get-IFXI2BSha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Get-IFXI2BTreeListing {
    # Regular files under $Root, excluding the named top-level entries; ordinal order of the relative path.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root, [string[]]$Exclude = @())
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('/', '\')
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($top in @(Get-ChildItem -LiteralPath $full -Force)) {
        if ($Exclude -ccontains $top.Name) { continue }
        $files = @(if ($top.PSIsContainer) { Get-ChildItem -LiteralPath $top.FullName -File -Recurse -Force } else { $top })
        foreach ($f in $files) {
            $rows.Add([pscustomobject]@{ path = [IO.Path]::GetRelativePath($full, $f.FullName).Replace('\', '/'); bytes = [long]$f.Length; sha256 = Get-IFXI2BSha256 $f.FullName })
        }
    }
    # List.Sort sorts in place; [Array]::Sort on a PowerShell-converted argument would sort a copy.
    $rows.Sort([Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.path, $b.path) })
    , $rows.ToArray()
}

function ConvertTo-IFXI2BListingText([object[]]$Listing) {
    # One line per file: "<sha256> <bytes> <path>", LF, UTF-8; the listing hash covers exactly this text.
    $sb = [Text.StringBuilder]::new()
    foreach ($r in $Listing) { [void]$sb.Append("$($r.sha256) $($r.bytes) $($r.path)`n") }
    $sb.ToString()
}

function Get-IFXI2BArchiveEntries([string]$ArchivePath) {
    # Regular-file entries of the gzip tar, relative, without a leading "./". GNU tar (Linux) and bsdtar
    # (Windows) both list directories with a trailing slash.
    $lines = @(& tar -tzf $ArchivePath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "tar listing failed ($LASTEXITCODE): $(@($lines | Select-Object -Last 3) -join '; ')" }
    $entries = @($lines | ForEach-Object { [string]$_ } | Where-Object { -not $_.EndsWith('/') } | ForEach-Object { if ($_.StartsWith('./')) { $_.Substring(2) } else { $_ } } | Where-Object { $_ -cne '' -and $_ -cne '.' })
    $sorted = [Collections.Generic.List[string]]::new([string[]]$entries)
    $sorted.Sort([StringComparer]::Ordinal)
    , $sorted.ToArray()
}

function Copy-IFXI2BNativeResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NativeRoot,
        [Parameter(Mandatory)][string]$OutRoot,
        [string[]]$Exclude = @(),
        # Report files copied individually (relative to NativeRoot); every top-level file and every file that
        # matches ReportFilter are copied too. Missing reports are recorded, not fatal (a failed run may stop early).
        [string[]]$Reports = @('summary.json', 'positive.json', 'matrix/summary.json', 'matrix/case-manifest.json', 'matrix/matrix-contract-summary.json'),
        [string]$ReportFilter = 'linux-failure-*.json',
        [string]$ArchiveName = 'native-results.tar.gz'
    )
    # Runs in a finally block: it reports, and never masks the original outcome with its own failure.
    $manifestPath = Join-Path $OutRoot 'native-copyback.json'
    $timings = [ordered]@{}
    $manifest = [ordered]@{ formatVersion = 1; kind = 'ifx-i2b-linux-native-archive-copyback'; status = 'fail'; nativeRoot = $NativeRoot; outRoot = $OutRoot; excluded = @($Exclude); diagnostics = @() }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        [void][IO.Directory]::CreateDirectory($OutRoot)
        if (-not (Test-Path -LiteralPath $NativeRoot -PathType Container)) { throw "Native root is missing: $NativeRoot" }
        $native = [IO.Path]::GetFullPath($NativeRoot).TrimEnd('/')
        $stagingArchive = Join-Path ([IO.Path]::GetDirectoryName($native)) ("$([IO.Path]::GetFileName($native))-$ArchiveName")
        if (Test-Path -LiteralPath $stagingArchive) { Remove-Item -LiteralPath $stagingArchive -Force }

        $t = [Diagnostics.Stopwatch]::StartNew()
        $listing = Get-IFXI2BTreeListing -Root $native -Exclude $Exclude
        $timings.listSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)

        $t.Restart()
        $tarArgs = @('--sort=name', '--format=pax', '--numeric-owner', '-czf', $stagingArchive, '-C', $native)
        foreach ($e in $Exclude) { $tarArgs += "--exclude=./$e" }
        $tarArgs += '.'
        $tarOut = @(& tar @tarArgs 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "tar create failed ($LASTEXITCODE): $($tarOut -join '; ')" }
        $timings.archiveSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)

        # The archive must hold exactly the listed files before it leaves native storage.
        $t.Restart()
        $entries = Get-IFXI2BArchiveEntries $stagingArchive
        $expected = [string[]]@($listing | ForEach-Object { $_.path })
        if (($entries -join "`n") -cne ($expected -join "`n")) { throw "Native archive entries differ from the native listing (archive $($entries.Count), native $($expected.Count))." }
        $archiveSha = Get-IFXI2BSha256 $stagingArchive
        $timings.verifyNativeSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)

        $t.Restart()
        $outArchive = Join-Path $OutRoot $ArchiveName
        Copy-Item -LiteralPath $stagingArchive -Destination $outArchive -Force
        $copiedSha = Get-IFXI2BSha256 $outArchive
        if ($copiedSha -cne $archiveSha) { throw "Copied archive hash differs: native $archiveSha, copied $copiedSha" }
        $timings.copyArchiveSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)

        $t.Restart()
        $listingText = ConvertTo-IFXI2BListingText $listing
        $listingPath = Join-Path $OutRoot 'native-listing.txt'
        [IO.File]::WriteAllText($listingPath, $listingText, [Text.UTF8Encoding]::new($false))
        $byPath = @{}; foreach ($r in $listing) { $byPath[$r.path] = $r }
        $wanted = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
        foreach ($r in $listing) {
            if ($r.path -notmatch '/') { [void]$wanted.Add($r.path) }
            elseif ([IO.Path]::GetFileName($r.path) -like $ReportFilter) { [void]$wanted.Add($r.path) }
        }
        foreach ($r in $Reports) { [void]$wanted.Add($r.Replace('\', '/')) }
        $reportRows = [Collections.Generic.List[object]]::new()
        foreach ($rel in $wanted) {
            if (-not $byPath.ContainsKey($rel)) { $reportRows.Add([ordered]@{ path = $rel; present = $false }); continue }
            $destination = Join-Path $OutRoot $rel
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
            Copy-Item -LiteralPath (Join-Path $native $rel) -Destination $destination -Force
            $sha = Get-IFXI2BSha256 $destination
            if ($sha -cne $byPath[$rel].sha256) { throw "Copied report differs from the native file: $rel" }
            $reportRows.Add([ordered]@{ path = $rel; present = $true; bytes = $byPath[$rel].bytes; sha256 = $sha })
        }
        $timings.copyReportsSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
        Remove-Item -LiteralPath $stagingArchive -Force

        $manifest.status = 'pass'
        $manifest.archive = [ordered]@{ path = $ArchiveName; format = 'tar (pax, sorted, gzip)'; bytes = (Get-Item -LiteralPath $outArchive).Length; sha256 = $copiedSha; fileEntries = $entries.Count }
        $manifest.listing = [ordered]@{ path = 'native-listing.txt'; files = $listing.Count; bytes = $(if ($listing.Count -eq 0) { [long]0 } else { [long](($listing | Measure-Object bytes -Sum).Sum) }); sha256 = Get-IFXI2BSha256 $listingPath; lineFormat = '<sha256> <bytes> <path>' }
        $manifest.reports = @($reportRows.ToArray())
    } catch {
        $manifest.diagnostics = @($_.Exception.Message)
        Write-Warning "Native result archive copy-back failed: $($_.Exception.Message)"
    } finally {
        $timings.totalSeconds = [math]::Round($clock.Elapsed.TotalSeconds, 3)
        $manifest.timings = $timings
        try {
            [void][IO.Directory]::CreateDirectory($OutRoot)
            [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
        } catch { Write-Warning "Native copy-back manifest could not be written: $($_.Exception.Message)" }
    }
}

function Test-IFXI2BNativeArchive {
    # Re-checks an archive copy-back on the receiving side (Windows or Linux): the manifest passed, the archive
    # hash matches, the archive entries equal the listing, and each copied report equals its listing row and its
    # archived bytes. -Deep extracts the whole archive and checks every listed hash. Throws on any mismatch.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$OutRoot, [switch]$Deep)
    $manifestPath = Join-Path $OutRoot 'native-copyback.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Copy-back manifest is missing: $manifestPath" }
    $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 20
    if ($m.kind -cne 'ifx-i2b-linux-native-archive-copyback') { throw "Unexpected copy-back manifest kind: $($m.kind)" }
    if ($m.status -cne 'pass') { throw "Copy-back did not pass: $(@($m.diagnostics) -join '; ')" }
    $archive = Join-Path $OutRoot $m.archive.path
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) { throw "Archive is missing: $archive" }
    if ((Get-IFXI2BSha256 $archive) -cne $m.archive.sha256) { throw 'Archive hash differs from the manifest.' }
    $listingPath = Join-Path $OutRoot $m.listing.path
    if ((Get-IFXI2BSha256 $listingPath) -cne $m.listing.sha256) { throw 'Listing hash differs from the manifest.' }
    $listing = @([IO.File]::ReadAllText($listingPath).Split("`n", [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
        $parts = $_.Split(' ', 3); [pscustomobject]@{ sha256 = $parts[0]; bytes = [long]$parts[1]; path = $parts[2] } })
    if ($listing.Count -ne [int]$m.listing.files) { throw 'Listing line count differs from the manifest.' }
    $entries = Get-IFXI2BArchiveEntries $archive
    $expected = [string[]]@($listing | ForEach-Object { $_.path })
    if (($entries -join "`n") -cne ($expected -join "`n")) { throw "Archive entries differ from the listing (archive $($entries.Count), listing $($expected.Count))." }
    $byPath = @{}; foreach ($r in $listing) { $byPath[$r.path] = $r }
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ("ifxi2b-verify-" + [guid]::NewGuid().ToString('n'))
    [void][IO.Directory]::CreateDirectory($scratch)
    try {
        $present = @($m.reports | Where-Object { $_.present })
        if ($Deep) { $x = @(& tar -xzf $archive -C $scratch 2>&1); if ($LASTEXITCODE -ne 0) { throw "Archive extraction failed: $($x -join '; ')" } }
        elseif ($present.Count -gt 0) {
            $x = @(& tar -xzf $archive -C $scratch @($present | ForEach-Object { "./$($_.path)" }) 2>&1); if ($LASTEXITCODE -ne 0) { throw "Report extraction failed: $($x -join '; ')" }
        }
        foreach ($r in $present) {
            if (-not $byPath.ContainsKey($r.path)) { throw "Report is not in the listing: $($r.path)" }
            $copied = Join-Path $OutRoot $r.path
            if (-not (Test-Path -LiteralPath $copied -PathType Leaf)) { throw "Copied report is missing: $($r.path)" }
            $copiedSha = Get-IFXI2BSha256 $copied
            if ($copiedSha -cne $r.sha256 -or $copiedSha -cne $byPath[$r.path].sha256) { throw "Copied report differs from the manifest or listing: $($r.path)" }
            if ((Get-IFXI2BSha256 (Join-Path $scratch $r.path)) -cne $copiedSha) { throw "Copied report differs from its archived bytes: $($r.path)" }
        }
        if ($Deep) {
            foreach ($r in $listing) {
                $f = Join-Path $scratch $r.path
                if (-not (Test-Path -LiteralPath $f -PathType Leaf) -or (Get-IFXI2BSha256 $f) -cne $r.sha256) { throw "Archived file differs from the listing: $($r.path)" }
            }
        }
    } finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
    [ordered]@{ archiveSha256 = $m.archive.sha256; files = $listing.Count; reports = $present.Count; deep = [bool]$Deep }
}

Export-ModuleMember -Function Copy-IFXI2BNativeResults, Test-IFXI2BNativeArchive, Get-IFXI2BTreeListing
