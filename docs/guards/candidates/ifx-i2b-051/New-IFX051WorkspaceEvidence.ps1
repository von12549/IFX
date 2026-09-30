# IFX I2-B amendment A2 step A2-6: successor of candidates/ifx-workspace-evidence/New-IFXWorkspaceEvidence.ps1 (unchanged)
# for the 0.5.1 focused qualification. The roots are the composed Profile's workspaceEvidence.relativeRoots, which in 0.5.1
# name the relocated database producer instead of the V3_ifx specialized gate; everything else is unchanged.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TargetRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    # Comma-separated (pwsh -File passes one string).
    [Parameter(Mandatory)][string]$RelativeRoots
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ifx-workspace-evidence/IFX.Guard.Common.psm1') -Force

$target = [IO.Path]::GetFullPath($TargetRoot)
$output = [IO.Path]::GetFullPath($OutputPath)
if (-not [IO.Directory]::Exists($target)) { throw 'TargetRoot is missing.' }
if (Test-IFXUnderRoot $output $target) { throw 'Workspace evidence must be outside TargetRoot.' }

$started = [DateTimeOffset]::UtcNow
$watch = [Diagnostics.Stopwatch]::StartNew()
$roots = @($RelativeRoots -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$extensions = @('.cs','.csproj','.json','.ps1')
$paths = @(Get-IFXWorkspaceFiles -TargetRoot $target -RelativeRoots $roots -Extensions $extensions)
$entries = [Collections.Generic.List[object]]::new()
foreach ($relative in $paths) {
    $full = Join-Path $target $relative
    $bytes = [IO.File]::ReadAllBytes($full)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $normalized = $text.ReplaceLineEndings("`n")
    $entries.Add([ordered]@{
        path = $relative
        extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
        length = $bytes.Length
        sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        normalizedSha256 = Get-IFXTextSha256 $normalized
        text = $text
    })
}
$lines = @($entries | ForEach-Object { "$($_.path)|$($_.sha256)" }) -join "`n"
$commit = (& git -C $target rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Target commit is unavailable.' }
$watch.Stop()
$document = [ordered]@{
    formatVersion = 1
    scope = 'v4-workspace-evidence-v1'
    targetCommit = $commit
    relativeRoots = $roots
    extensions = $extensions
    excludedDirectoryNames = @('bin','obj','node_modules','dist','coverage','.vite','.git','artifacts')
    pathOrder = 'ordinal'
    fileCount = $entries.Count
    treeSha256 = Get-IFXTextSha256 $lines
    startedAt = $started.ToString('o')
    completedAt = [DateTimeOffset]::UtcNow.ToString('o')
    elapsedSeconds = [math]::Round($watch.Elapsed.TotalSeconds,3)
    files = @($entries.ToArray())
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))
$temporary = "$output.$([guid]::NewGuid().ToString('N')).tmp"
[IO.File]::WriteAllText($temporary,(($document | ConvertTo-Json -Depth 20).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false))
[IO.File]::Move($temporary,$output,$true)
[ordered]@{status='pass';path=$output;sha256=Get-IFXSha256 $output;fileCount=$entries.Count;treeSha256=$document.treeSha256;elapsedSeconds=$document.elapsedSeconds} | ConvertTo-Json -Compress
