# Plan 06 D14 trusted guard build support.
#
# Every restore, build, test and run of a trusted guard project goes through this module so that:
#   - the SDK is selected by build/global.json (commands run from the build directory),
#   - only build/NuGet.config supplies package sources,
#   - build/V3.Build.props is imported explicitly and every directory-based import is disabled,
#   - bin/obj go to an artifacts path instead of the source tree,
#   - NuGet restore is checked against a reviewed lock file (the lock must exist, must not change during
#     restore, and must agree with project.assets.json and the package content hash),
#   - the effective import set is checked before the build (msbuild -pp) and after it (import log).
# NuGet's own locked mode does not fail on a missing or edited lock in every case, so the lock checks below
# are enforced by this module rather than delegated to NuGet.

Set-StrictMode -Version Latest

$script:BuildRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:PathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

function ConvertTo-GuardPath([string] $Path) {
    # msbuild -pp writes paths inside XML comments, where '--' is escaped as '__'; compare in that form.
    $full = [IO.Path]::GetFullPath($Path).Replace('\', '/')
    return $full.Replace('--', '__')
}

function Test-GuardPathUnder([string] $Path, [string] $Root) {
    $prefix = (ConvertTo-GuardPath $Root).TrimEnd('/') + '/'
    return (ConvertTo-GuardPath $Path).StartsWith($prefix, $script:PathComparison)
}

function New-GuardBuildContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ArtifactsRoot,
        [Parameter(Mandatory)][string] $LockRoot,
        [Parameter(Mandatory)][string] $ReportRoot,
        [ValidateSet('Locked', 'Update')][string] $LockMode = 'Locked',
        [string] $NuGetConfig
    )
    $config = if ($NuGetConfig) { [IO.Path]::GetFullPath($NuGetConfig) } else { Join-Path $script:BuildRoot 'NuGet.config' }
    if (-not [IO.File]::Exists($config)) { throw "Guard NuGet config is missing: $config" }
    $lock = [IO.Path]::GetFullPath($LockRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, '/') + [IO.Path]::DirectorySeparatorChar
    [void][IO.Directory]::CreateDirectory($lock)
    [void][IO.Directory]::CreateDirectory($ReportRoot)
    $baseline = Join-Path $script:BuildRoot 'V3.Build.props'
    $context = [pscustomobject]@{
        BuildRoot = $script:BuildRoot
        Baseline = $baseline
        NuGetConfig = $config
        ArtifactsRoot = [IO.Path]::GetFullPath($ArtifactsRoot)
        LockRoot = $lock
        LockMode = $LockMode
        ReportRoot = [IO.Path]::GetFullPath($ReportRoot)
        Properties = @(
            '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
            '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
            '-p:ImportUserLocationsByWildcardBeforeMicrosoftCommonProps=false', '-p:ImportUserLocationsByWildcardAfterMicrosoftCommonProps=false',
            '-p:ImportUserLocationsByWildcardBeforeMicrosoftCommonTargets=false', '-p:ImportUserLocationsByWildcardAfterMicrosoftCommonTargets=false',
            "-p:CustomBeforeMicrosoftCommonProps=$baseline", "-p:GuardLockRoot=$lock"
        )
        DotnetRoot = $null
        PackageRoot = $null
    }
    $probeArguments = @('msbuild', (Join-Path $script:BuildRoot 'probe/Probe.csproj'), '-nologo', "-p:ArtifactsPath=$($context.ArtifactsRoot)", '-p:UseArtifactsOutput=true', '-getProperty:NetCoreRoot', '-getProperty:MSBuildExtensionsPath') + $context.Properties
    $probe = Invoke-GuardDotnet $context $probeArguments -Capture
    $context.DotnetRoot = [string](($probe -join "`n") | ConvertFrom-Json).Properties.NetCoreRoot
    # NuGetPackageRoot only exists after restore; ask NuGet for the global packages folder it will use.
    $locals = Invoke-GuardDotnet $context @('nuget', 'locals', 'global-packages', '--list') -Capture
    $match = [Regex]::Match(($locals -join "`n"), 'global-packages:\s*(.+)')
    if ($match.Success) { $context.PackageRoot = $match.Groups[1].Value.Trim() }
    if (-not $context.DotnetRoot -or -not $context.PackageRoot) { throw 'Cannot determine the .NET root or NuGet package root for the guard build.' }
    return $context
}

function Invoke-GuardDotnet {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)] $Context, [Parameter(Mandatory, Position = 1)][string[]] $Arguments, [switch] $Capture, [hashtable] $Environment = @{})
    $saved = @{}
    foreach ($key in $Environment.Keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process'); [Environment]::SetEnvironmentVariable($key, $Environment[$key], 'Process') }
    Push-Location $Context.BuildRoot
    try {
        if ($Capture) {
            $output = @(& dotnet @Arguments 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "dotnet $($Arguments[0]) failed with exit code ${LASTEXITCODE}: $($output -join ' | ')" }
            return $output
        }
        & dotnet @Arguments
        if ($LASTEXITCODE -ne 0) { throw "dotnet $($Arguments[0]) failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
        foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
    }
}

function Get-GuardLockPath($Context, [string] $Project) {
    return Join-Path $Context.LockRoot ("{0}.packages.lock.json" -f [IO.Path]::GetFileNameWithoutExtension($Project))
}

function Get-GuardHash([string] $Path) {
    # NuGet rewrites lock files with platform line endings even in locked mode; compare normalized text.
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
}

function Get-GuardLockedPackages($Context, [string] $Project) {
    $lock = Get-Content -LiteralPath (Get-GuardLockPath $Context $Project) -Raw | ConvertFrom-Json -AsHashtable -Depth 20
    $packages = @{}
    foreach ($framework in $lock.dependencies.Keys) {
        foreach ($name in $lock.dependencies[$framework].Keys) {
            $entry = $lock.dependencies[$framework][$name]
            if ($entry.type -eq 'Project') { continue }
            $key = "$($name.ToLowerInvariant())/$($entry.resolved.ToLowerInvariant())"
            $packages[$key] = [pscustomobject]@{ Id = $name; Version = [string]$entry.resolved; ContentHash = [string]$entry.contentHash }
        }
    }
    return $packages
}

function Invoke-GuardRestore {
    <#
      Restores a guard solution or project and verifies each listed project's lock file, assets, package
      content hashes, effective baseline properties and pre-build import set.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Target, [Parameter(Mandatory)][string[]] $Projects)
    $before = @{}
    $originalBytes = @{}
    foreach ($project in $Projects) {
        $lockPath = Get-GuardLockPath $Context $project
        if ($Context.LockMode -eq 'Locked') {
            if (-not [IO.File]::Exists($lockPath)) { throw "Guard lock file is missing for $([IO.Path]::GetFileName($project)): $lockPath. Run with -LockMode Update and review the new lock file." }
            $before[$project] = Get-GuardHash $lockPath
            $originalBytes[$project] = [IO.File]::ReadAllBytes($lockPath)
        }
    }
    $arguments = @('restore', $Target, '--configfile', $Context.NuGetConfig, '--force-evaluate', '--artifacts-path', $Context.ArtifactsRoot, '-nologo') + $Context.Properties
    if ($Context.LockMode -eq 'Locked') { $arguments += @('--locked-mode', '-p:RestoreLockedMode=true') }
    Invoke-GuardDotnet $Context $arguments
    foreach ($project in $Projects) {
        $lockPath = Get-GuardLockPath $Context $project
        if (-not [IO.File]::Exists($lockPath)) { throw "Restore did not produce a lock file for $([IO.Path]::GetFileName($project))." }
        if ($Context.LockMode -eq 'Locked') {
            $changed = (Get-GuardHash $lockPath) -ne $before[$project]
            # Keep the reviewed bytes in place whatever NuGet wrote, so a locked run never edits the lock file.
            [IO.File]::WriteAllBytes($lockPath, $originalBytes[$project])
            if ($changed) { throw "Guard lock file changed during locked restore: $lockPath" }
        }
        else {
            [IO.File]::WriteAllText($lockPath, [IO.File]::ReadAllText($lockPath).Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
        }
        Assert-GuardLockIntegrity $Context $project
        Assert-GuardEffectiveProperties $Context $project
        Assert-GuardImports $Context $project (Get-GuardPreprocessedImports $Context $project) 'pre-build'
    }
}

function Assert-GuardLockIntegrity {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Project)
    $name = [IO.Path]::GetFileNameWithoutExtension($Project)
    $locked = Get-GuardLockedPackages $Context $Project
    $assetsPath = Join-Path $Context.ArtifactsRoot "obj/$name/project.assets.json"
    if (-not [IO.File]::Exists($assetsPath)) { throw "Restore assets are missing for ${name}: $assetsPath" }
    $assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    $restored = @{}
    foreach ($library in $assets.libraries.Keys) {
        $item = $assets.libraries[$library]
        if ($item.type -ne 'package') { continue }
        $restored[$library.ToLowerInvariant()] = [string]$item.sha512
    }
    $missing = @($restored.Keys | Where-Object { -not $locked.ContainsKey($_) })
    $extra = @($locked.Keys | Where-Object { -not $restored.ContainsKey($_) })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) { throw "Lock file and restore assets disagree for ${name}: not locked [$($missing -join ', ')]; locked but not restored [$($extra -join ', ')]" }
    foreach ($key in $locked.Keys) {
        $entry = $locked[$key]
        if ($restored[$key] -cne $entry.ContentHash) { throw "Content hash mismatch between lock and assets for $($entry.Id) $($entry.Version) ($name)." }
        $folder = Join-Path $Context.PackageRoot "$($entry.Id.ToLowerInvariant())/$($entry.Version.ToLowerInvariant())"
        $metadata = Join-Path $folder '.nupkg.metadata'
        $sha = Join-Path $folder "$($entry.Id.ToLowerInvariant()).$($entry.Version.ToLowerInvariant()).nupkg.sha512"
        $actual = if ([IO.File]::Exists($metadata)) { [string](Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json).contentHash }
                  elseif ([IO.File]::Exists($sha)) { ([IO.File]::ReadAllText($sha)).Trim() }
                  else { $null }
        if ($actual -cne $entry.ContentHash) { throw "Package content hash does not match the lock for $($entry.Id) $($entry.Version): $folder" }
    }
}

function Assert-GuardEffectiveProperties {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Project)
    $names = @('GuardBuildBaseline', 'NuGetAudit', 'NuGetAuditMode', 'NuGetAuditLevel', 'WarningsAsErrors', 'ManagePackageVersionsCentrally', 'RestorePackagesWithLockFile', 'NuGetLockFilePath', 'DirectoryBuildPropsPath', 'DirectoryPackagesPropsPath')
    $arguments = @('msbuild', $Project, '-nologo', "-p:ArtifactsPath=$($Context.ArtifactsRoot)", '-p:UseArtifactsOutput=true') + $Context.Properties + @($names | ForEach-Object { "-getProperty:$_" })
    $properties = ((Invoke-GuardDotnet $Context $arguments -Capture) -join "`n" | ConvertFrom-Json).Properties
    $problems = [Collections.Generic.List[string]]::new()
    if ($properties.GuardBuildBaseline -ne 'v3') { $problems.Add('V3.Build.props was not imported') }
    if ($properties.NuGetAudit -ne 'true' -or $properties.NuGetAuditMode -ne 'all' -or $properties.NuGetAuditLevel -notin @('low', 'moderate')) { $problems.Add("NuGet audit is weaker than the baseline ($($properties.NuGetAudit)/$($properties.NuGetAuditMode)/$($properties.NuGetAuditLevel))") }
    foreach ($code in @('NU1603', 'NU1903', 'NU1904')) { if (@($properties.WarningsAsErrors -split ';' | Where-Object { $_.Trim() -eq $code }).Count -eq 0) { $problems.Add("$code is not an error") } }
    if ($properties.ManagePackageVersionsCentrally -eq 'true') { $problems.Add('central package management is enabled') }
    if ($properties.RestorePackagesWithLockFile -ne 'true') { $problems.Add('lock files are disabled') }
    if ((ConvertTo-GuardPath $properties.NuGetLockFilePath) -ne (ConvertTo-GuardPath (Get-GuardLockPath $Context $Project))) { $problems.Add("lock path is $($properties.NuGetLockFilePath)") }
    if ($properties.DirectoryBuildPropsPath -or $properties.DirectoryPackagesPropsPath) { $problems.Add('a Directory.*.props file was discovered') }
    if ($problems.Count -gt 0) { throw "Guard build baseline is not effective for $([IO.Path]::GetFileName($Project)): $($problems -join '; ')" }
}

function Get-GuardPreprocessedImports {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Project)
    $name = [IO.Path]::GetFileNameWithoutExtension($Project)
    $file = Join-Path $Context.ReportRoot "$name.preprocessed.xml"
    Invoke-GuardDotnet $Context (@('msbuild', $Project, '-nologo', "-pp:$file", "-p:ArtifactsPath=$($Context.ArtifactsRoot)", '-p:UseArtifactsOutput=true') + $Context.Properties) -Capture | Out-Null
    try {
        $imports = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $inComment = $false; $sawSeparator = $false
        foreach ($line in [IO.File]::ReadLines($file)) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith('<!--')) { $inComment = $true; $sawSeparator = $false; continue }
            if ($trimmed.EndsWith('-->')) { $inComment = $false; continue }
            if (-not $inComment) { continue }
            if ($trimmed.StartsWith('=====')) { $sawSeparator = $true; continue }
            if ($sawSeparator -and ($trimmed -match '^[A-Za-z]:[\\/]' -or $trimmed.StartsWith('/'))) { [void]$imports.Add($trimmed) }
        }
        return @($imports)
    }
    finally { if ([IO.File]::Exists($file)) { [IO.File]::Delete($file) } }
}

function Get-GuardLogImports([string] $LogFile) {
    $imports = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in [IO.File]::ReadLines($LogFile)) {
        $match = [Regex]::Match($line, 'Importing project "([^"]+)" into project')
        if ($match.Success) { [void]$imports.Add($match.Groups[1].Value) }
    }
    return @($imports)
}

function Assert-GuardImports {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Project, [string[]] $Imports, [Parameter(Mandatory)][string] $Phase, [string[]] $Projects = @())
    $allowedProjects = @(@($Project) + $Projects | ForEach-Object { ConvertTo-GuardPath $_ })
    $lockedByProject = @{}
    foreach ($candidate in @(@($Project) + $Projects)) {
        foreach ($entry in (Get-GuardLockedPackages $Context $candidate).Values) { $lockedByProject["$($entry.Id.ToLowerInvariant())/$($entry.Version.ToLowerInvariant())"] = $true }
    }
    $violations = [Collections.Generic.List[string]]::new()
    $categories = [ordered]@{ sdk = 0; baseline = 0; restoreGenerated = 0; lockedPackage = 0; project = 0 }
    foreach ($import in @($Imports)) {
        if ($allowedProjects -contains (ConvertTo-GuardPath $import)) { $categories.project++; continue }
        if (Test-GuardPathUnder $import $Context.DotnetRoot) { $categories.sdk++; continue }
        if ((ConvertTo-GuardPath $import) -eq (ConvertTo-GuardPath $Context.Baseline)) { $categories.baseline++; continue }
        if ((Test-GuardPathUnder $import (Join-Path $Context.ArtifactsRoot 'obj')) -and ([IO.Path]::GetFileName($import) -match '\.nuget\.g\.(props|targets)$')) { $categories.restoreGenerated++; continue }
        if (Test-GuardPathUnder $import $Context.PackageRoot) {
            $relative = (ConvertTo-GuardPath $import).Substring((ConvertTo-GuardPath $Context.PackageRoot).TrimEnd('/').Length + 1)
            $parts = $relative.Split('/')
            if ($parts.Count -ge 3 -and $lockedByProject.ContainsKey("$($parts[0].ToLowerInvariant())/$($parts[1].ToLowerInvariant())")) { $categories.lockedPackage++; continue }
        }
        $violations.Add($import)
    }
    $name = [IO.Path]::GetFileNameWithoutExtension($Project)
    $report = [ordered]@{ formatVersion = 1; project = $name; phase = $Phase; status = if ($violations.Count -eq 0) { 'pass' } else { 'fail' }; imports = @($Imports).Count; categories = $categories; violations = @($violations) }
    [IO.File]::WriteAllText((Join-Path $Context.ReportRoot "$name.imports.$Phase.json"), (($report | ConvertTo-Json -Depth 5).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    if ($violations.Count -gt 0) { throw "Guard build imported files outside the allowlist ($Phase, $name): $($violations -join '; ')" }
}

function Invoke-GuardBuildStep {
    <#
      Runs dotnet build/test with the guard properties and a diagnostic import log, then checks the imports
      recorded for every listed project against the allowlist.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][ValidateSet('build', 'test')][string] $Verb, [Parameter(Mandatory)][string] $Target, [Parameter(Mandatory)][string[]] $Projects, [string[]] $ExtraArguments = @())
    $log = Join-Path $Context.ReportRoot ("{0}.{1}.imports.log" -f [IO.Path]::GetFileNameWithoutExtension($Target), $Verb)
    $arguments = @($Verb, $Target, '--no-restore', '--artifacts-path', $Context.ArtifactsRoot, '-nologo', "-flp:v=diag;logfile=$log") + $Context.Properties + $ExtraArguments
    $failure = $null
    try { Invoke-GuardDotnet $Context $arguments -Environment @{ MSBUILDLOGIMPORTS = '1' } }
    catch { $failure = $_ }
    try {
        if ([IO.File]::Exists($log)) {
            $imports = Get-GuardLogImports $log
            $files = @($Projects | ForEach-Object { [IO.Path]::GetFullPath($_) })
            Assert-GuardImports $Context $files[0] $imports 'post-build' @($files | Select-Object -Skip 1)
        } elseif ($null -eq $failure) { throw "Guard build did not write its import log: $log" }
    }
    finally { if ([IO.File]::Exists($log)) { [IO.File]::Delete($log) } }
    if ($null -ne $failure) { throw $failure }
}

function Assert-GuardNoSourceTreeOutput {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root)
    if (-not [IO.Directory]::Exists($Root)) { return }
    $found = @(Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force | Where-Object { $_.Name -in @('bin', 'obj') } | ForEach-Object { $_.FullName })
    if ($found.Count -gt 0) { throw "Build output was written into the source tree: $($found -join ', ')" }
}

Export-ModuleMember -Function New-GuardBuildContext, Invoke-GuardDotnet, Invoke-GuardRestore, Invoke-GuardBuildStep, Assert-GuardLockIntegrity, Assert-GuardEffectiveProperties, Assert-GuardImports, Get-GuardPreprocessedImports, Assert-GuardNoSourceTreeOutput
