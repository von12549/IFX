[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $PolicyPath = 'src/layerguard.json',
    [string[]] $AssemblyPaths = @(),
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [string] $ReportPath = 'artifacts/guards/domain-assembly-result.json'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GuardCore.psm1') -Force
$root = Get-GuardRoot $RepositoryRoot
if (-not (Test-GuardGlob ($ReportPath.Replace('\', '/')) 'artifacts/guards/**')) { throw 'Assembly guard report must be under artifacts/guards/.' }
$output = Resolve-GuardPath $root $ReportPath
$report = [ordered]@{
    formatVersion = 1; gateId = 'assembly-domain-boundary'; stage = 'post'; status = 'blocked'
    scope = 'compiled-domain-assemblies'; ruleIds = @('L2.2'); inputHash = ''
    checks = @(); evidencePaths = @(); reason = ''
}
try {
    $policyFile = Resolve-GuardPath $root $PolicyPath -MustExist
    $policy = Get-Content -LiteralPath $policyFile -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    if (-not $policy.ContainsKey('allowedReferences') -or -not $policy.allowedReferences.ContainsKey('Domain')) {
        throw 'Policy has no allowedReferences.Domain authority.'
    }
    $allowed = @($policy.allowedReferences.Domain)
    $report.inputHash = Get-GuardTextHash $policyFile
    $trusted = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $platformAssemblies = [string] [AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES')
    if (-not $platformAssemblies) { throw 'Cannot identify trusted platform assemblies.' }
    foreach ($path in $platformAssemblies.Split([IO.Path]::PathSeparator)) {
        [void] $trusted.Add([IO.Path]::GetFileNameWithoutExtension($path))
    }
    if ($AssemblyPaths.Count -eq 0) {
        $sourceRoot = Resolve-GuardPath $root 'src' -MustExist
        $projects = @([IO.Directory]::EnumerateFiles($sourceRoot, 'IFX.Modules.*.Domain.csproj', [IO.SearchOption]::AllDirectories) | Sort-Object)
        if ($projects.Count -eq 0) { throw 'No module Domain projects were found.' }
        $AssemblyPaths = @($projects | ForEach-Object {
            $name = [IO.Path]::GetFileNameWithoutExtension($_)
            [IO.Path]::GetRelativePath($root, (Join-Path ([IO.Path]::GetDirectoryName($_)) "bin/$Configuration/net8.0/$name.dll")).Replace('\', '/')
        })
    }
    $checks = [Collections.Generic.List[object]]::new()
    foreach ($relative in $AssemblyPaths) {
        $dll = Resolve-GuardPath $root $relative -MustExist
        if (-not [IO.File]::Exists($dll)) { throw "Domain assembly is not a file: $relative" }
        $assembly = [Reflection.Assembly]::LoadFrom($dll)
        $references = @($assembly.GetReferencedAssemblies() | ForEach-Object { $_.Name } | Sort-Object -Unique)
        $forbidden = @($references | Where-Object {
            $reference = $_
            -not $trusted.Contains($reference) -and
            @($allowed | Where-Object { Test-GuardGlob $reference $_ }).Count -eq 0
        })
        $checks.Add([ordered]@{
            id = [IO.Path]::GetFileNameWithoutExtension($relative)
            assemblyPath = $relative.Replace('\', '/')
            status = $(if ($forbidden.Count -eq 0) { 'pass' } else { 'fail' })
            referencedAssemblies = $references
            forbiddenReferences = $forbidden
        })
    }
    $report.checks = @($checks)
    $report.status = if (@($checks | Where-Object { $_.status -eq 'fail' }).Count -gt 0) { 'fail' } else { 'pass' }
    $report.reason = if ($report.status -eq 'pass') { 'Compiled Domain assemblies have only policy-allowed direct assembly references.' } else { 'A compiled Domain assembly directly references an assembly outside allowedReferences.Domain.' }
}
catch {
    $report.status = 'blocked'
    $report.reason = $_.Exception.Message
}
Write-GuardText $output (ConvertTo-GuardJson $report)
if (-not (Test-Json -Path $output -SchemaFile (Resolve-GuardPath $root 'docs/guards/contracts/guard-result.schema.json' -MustExist) -ErrorAction Stop)) {
    throw 'Domain assembly guard result schema validation failed.'
}
Write-Host "Domain assembly guard status: $($report.status). Report: $ReportPath"
if ($report.status -ne 'pass') { exit 1 }
