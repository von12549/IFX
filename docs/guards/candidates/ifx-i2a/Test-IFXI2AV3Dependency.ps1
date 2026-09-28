# IFX I2-A (Plan 20260929-v4-ifx-i2a-installed-webui) step A6: the composed V4 package must have no V3 runtime
# dependency. Executable and configuration files (scripts, modules, JSON authorities, locks, assemblies) must not
# name the V3 or V3_ifx roots, a V3 command or the LayerGuard tool, in any letter case. Documentation mentions
# are listed separately and do not fail the check.
[CmdletBinding()]
param(
    [string] $InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4',
    [string] $OutputPath = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/i2a-webui-044/v3-dependency-scan.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw "Output already exists: $OutputPath" }
$patterns = [ordered]@{
    'v3-root' = '(?i)docs[/\\]guards[/\\]V3(_ifx)?([/\\]|\b)'
    'v3-ifx-name' = '(?i)\bV3_ifx\b'
    'v3-command' = '(?i)\b(Invoke-V3(Setup|Docs)?|Invoke-IFXGuardrails|Invoke-IFXTrustedBase|Invoke-IFXArchitecture)\b'
    'layerguard' = '(?i)layer-?guard'
}
$docExtensions = @('.md', '.txt', '.html', '.htm')
$runtime = [Collections.Generic.List[object]]::new(); $docs = [Collections.Generic.List[object]]::new(); $scanned = 0
foreach ($file in Get-ChildItem -LiteralPath $InstallRoot -File -Recurse -Force) {
    $scanned++
    $relative = [IO.Path]::GetRelativePath($InstallRoot, $file.FullName).Replace('\', '/')
    # Binary files are read as Latin-1 so that embedded ASCII and UTF-8 names are still visible to the patterns.
    $text = if ($file.Extension -in @('.dll', '.exe', '.pdb')) { [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($file.FullName)) } else { [IO.File]::ReadAllText($file.FullName) }
    foreach ($name in $patterns.Keys) {
        $hits = [regex]::Matches($text, $patterns[$name])
        if ($hits.Count -eq 0) { continue }
        $row = [ordered]@{ path = $relative; pattern = $name; count = $hits.Count; sample = $hits[0].Value }
        if ($file.Extension.ToLowerInvariant() -in $docExtensions) { $docs.Add($row) } else { $runtime.Add($row) }
    }
}
$status = if ($runtime.Count -eq 0) { 'pass' } else { 'fail' }
[IO.File]::WriteAllText($OutputPath, (([ordered]@{ formatVersion = 1; step = 'A6'; status = $status; installRoot = $InstallRoot; scannedFiles = $scanned
    patterns = $patterns; runtimeReferences = @($runtime.ToArray()); documentationMentions = @($docs.ToArray()) } | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
"scanned=$scanned runtimeReferences=$($runtime.Count) documentationMentions=$($docs.Count) status=$status"
$runtime | ForEach-Object { "RUNTIME $($_.path) [$($_.pattern)] x$($_.count): $($_.sample)" }
if ($status -cne 'pass') { exit 1 }
