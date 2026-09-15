[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $PolicyPath = 'docs/guards/V3_ifx/policy/layerguard.json',
    [string[]] $AssemblyPaths = @(),
    [string] $DomainProjectRoot = 'src/Modules',
    [int] $ExpectedProjectCount = 5,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release',
    [string] $ReportPath = 'artifacts/guards/v3-ifx/quality/assembly.json'
)

$ErrorActionPreference = 'Stop'
$root = if ($RepositoryRoot) { [IO.Path]::GetFullPath($RepositoryRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
function Resolve-PathInRoot([string] $path) {
    $resolved = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }))
    $prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolved -ne $root -and -not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes repository root: $path" }
    $resolved
}

$output = Resolve-PathInRoot $ReportPath
$report = [ordered]@{ schemaVersion = 1; mode = 'quality'; detector = 'assembly'; status = 'blocked'; checks = @(); message = $null }
try {
    $policyFile = Resolve-PathInRoot $PolicyPath
    if (-not (Test-Path -LiteralPath $policyFile -PathType Leaf)) { throw "Policy is missing: $PolicyPath" }
    $policy = Get-Content -Raw -LiteralPath $policyFile | ConvertFrom-Json -Depth 100
    $allowed = @($policy.allowedReferences.Domain)
    if ($allowed.Count -eq 0) { throw 'Policy has no allowedReferences.Domain entries.' }

    $projectByAssembly = @{}
    if ($AssemblyPaths.Count -eq 0) {
        $projects = @(Get-ChildItem (Resolve-PathInRoot $DomainProjectRoot) -Recurse -File -Filter 'IFX.Modules.*.Domain.csproj' | Sort-Object FullName)
        if ($projects.Count -eq $ExpectedProjectCount) {
            foreach ($project in $projects) {
                $name = $project.BaseName
                $relative = [IO.Path]::GetRelativePath($root, (Join-Path $project.DirectoryName "bin/$Configuration/net8.0/$name.dll")).Replace('\','/')
                $AssemblyPaths += $relative
                $projectByAssembly[$relative] = $project.FullName
            }
        } else { throw "Expected $ExpectedProjectCount module Domain projects, found $($projects.Count)." }
    }

    $trusted = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in ([string][AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES')).Split([IO.Path]::PathSeparator)) {
        [void]$trusted.Add([IO.Path]::GetFileNameWithoutExtension($path))
    }
    $checks = @()
    foreach ($relative in $AssemblyPaths) {
        $dll = Resolve-PathInRoot $relative
        if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw "Domain assembly is missing: $relative" }
        $stale = $false
        if ($projectByAssembly.ContainsKey($relative)) {
            $projectRoot = Split-Path -Parent $projectByAssembly[$relative]
            $newestInput = Get-ChildItem $projectRoot -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            $stale = $newestInput.LastWriteTimeUtc -gt (Get-Item $dll).LastWriteTimeUtc
        }
        $references = @([Reflection.Assembly]::LoadFrom($dll).GetReferencedAssemblies().Name | Sort-Object -Unique)
        $forbidden = @($references | Where-Object {
            $reference = $_
            -not $trusted.Contains($reference) -and @($allowed | Where-Object { $reference -like $_ }).Count -eq 0
        })
        $checks += [ordered]@{ id = [IO.Path]::GetFileNameWithoutExtension($dll); assemblyPath = $relative.Replace('\','/'); status = if ($forbidden.Count -eq 0 -and -not $stale) { 'pass' } else { 'fail' }; stale = $stale; referencedAssemblies = $references; forbiddenReferences = $forbidden }
    }
    if ($checks.Count -eq 0) { throw 'Assembly selection matched zero files.' }
    $report.checks = $checks
    $report.status = if (@($checks | Where-Object status -eq 'fail').Count -eq 0) { 'pass' } else { 'fail' }
    $report.message = "$($checks.Count) compiled module Domain assemblies were inspected."
} catch {
    $report.status = 'blocked'
    $report.message = $_.Exception.Message
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
if ($report.status -ne 'pass') { throw "IFX assembly guard $($report.status): $($report.message). Report: $output" }
Write-Host "IFX assembly guard passed: $output"
