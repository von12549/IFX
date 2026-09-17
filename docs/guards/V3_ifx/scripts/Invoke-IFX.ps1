[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate', 'Generate', 'Check', 'Test', 'Scan')][string] $Mode,
    [string] $TargetRoot,
    [string] $ReportPath,
    [string] $NuGetConfig,
    [switch] $SkipAuthorityCheck,
    [ValidateSet('Locked', 'Update')][string] $LockMode = 'Locked',
    [string] $LockRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$target = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else {
    [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
}
$template = Join-Path $packageRoot 'templates/ifx-layerguard'
$generated = Join-Path $packageRoot 'generated/dotnet/LayerGuard'
$policy = Join-Path $packageRoot 'policy/layerguard.json'
$baseline = Join-Path $packageRoot 'policy/baselines/plan05.json'
$solution = Join-Path $generated 'LayerGuard.slnx'
$project = Join-Path $generated 'src/LayerGuard/LayerGuard.csproj'

function Get-SourceFiles {
    $files = @(Get-ChildItem -LiteralPath $template -Recurse -File | Sort-Object FullName)
    if ($files.Count -eq 0) { throw 'IFX LayerGuard template is empty.' }
    return $files
}

function Assert-LocalBinding {
    param([string] $Relative, [string] $Label)
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or
        $Relative -match '^[A-Za-z]:' -or $Relative -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Binding must be a package-local relative path: $Label"
    }
    $policyRoot = Split-Path -Parent $policy
    $resolved = [IO.Path]::GetFullPath((Join-Path $policyRoot $Relative))
    $prefix = $policyRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($resolved)) {
        throw "Package-local binding is missing: $Label ($Relative)"
    }
    return $resolved
}

function Assert-RuleAlignment {
    param([object] $Config)
    $ruleRoot = Join-Path $packageRoot 'profiles/ifx/rules'
    if (-not [IO.Directory]::Exists($ruleRoot)) { throw "IFX stage rules are missing: $ruleRoot" }
    $stageIds = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $ruleRoot -File -Filter '*.json')) {
        $stage = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        if ($file.BaseName -cne [string] $stage.id) { throw "Stage rule ID/file mismatch: $($file.Name)" }
        if ($stage.id -match '^L[0-9]+\.[0-9]+$') {
            if (-not ([string] $stage.authority).StartsWith('policy/layerguard.json:', [StringComparison]::Ordinal)) { throw "Stage rule lacks local LayerGuard authority: $($stage.id)" }
            $stageIds += [string] $stage.id
        }
    }
    $policyIds = @($Config.ruleRefs | ForEach-Object { [string] $_.ref })
    if (@($stageIds | Sort-Object -Unique).Count -ne $stageIds.Count -or @($policyIds | Sort-Object -Unique).Count -ne $policyIds.Count) { throw 'Duplicate numbered IFX rule ID.' }
    $missingInStage = @($policyIds | Where-Object { $_ -notin $stageIds })
    $missingInPolicy = @($stageIds | Where-Object { $_ -notin $policyIds })
    if ($missingInStage.Count -gt 0 -or $missingInPolicy.Count -gt 0) {
        throw "IFX stage/policy rule ID drift. Missing in stage: $($missingInStage -join ', '); missing in policy: $($missingInPolicy -join ', ')"
    }
}

function Assert-Inputs {
    if (-not [IO.Directory]::Exists((Join-Path $target 'src'))) { throw "Target src directory is missing: $target" }
    foreach ($file in @($policy, $baseline, (Join-Path $template 'LayerGuard.slnx'))) {
        if (-not [IO.File]::Exists($file)) { throw "IFX gate input is missing: $file" }
    }
    $config = Get-Content -LiteralPath $policy -Raw | ConvertFrom-Json -AsHashtable
    Assert-RuleAlignment $config
    foreach ($name in @('g03Governance', 'g04RuntimeManifest', 'g05ContextPolicy')) {
        $relative = [string] $config.gatePolicies[$name]
        [void] (Assert-LocalBinding $relative $name)
    }
    $g03Path = Assert-LocalBinding ([string] $config.gatePolicies.g03Governance) 'G03 governance'
    $g03 = Get-Content -LiteralPath $g03Path -Raw | ConvertFrom-Json -AsHashtable
    [void] (Assert-LocalBinding ([string] $g03.source) 'G03 catalog')
    $g04Path = Assert-LocalBinding ([string] $config.gatePolicies.g04RuntimeManifest) 'G04 manifest'
    $g04 = Get-Content -LiteralPath $g04Path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($name in @($g04.bindings.Keys)) {
        [void] (Assert-LocalBinding ([string] $g04.bindings[$name].path) "G04 $name")
    }
    [void] (Get-SourceFiles)
}

function Assert-Generated {
    if (-not [IO.Directory]::Exists($generated)) { throw "Generated .NET project is missing: $generated" }
    $expected = @(Get-SourceFiles | ForEach-Object { [IO.Path]::GetRelativePath($template, $_.FullName).Replace('\', '/') })
    foreach ($relative in $expected) {
        $source = Join-Path $template $relative
        $destination = Join-Path $generated $relative
        if (-not [IO.File]::Exists($destination)) { throw "Generated file is missing: $relative" }
        $left = [IO.File]::ReadAllBytes($source)
        $right = [IO.File]::ReadAllBytes($destination)
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $left, [byte[]] $right)) {
            throw "Generated file drift: $relative"
        }
    }
    $actual = @(Get-ChildItem -LiteralPath $generated -Recurse -File | ForEach-Object {
        [IO.Path]::GetRelativePath($generated, $_.FullName).Replace('\', '/')
    } | Where-Object { $_ -notmatch '(^|/)(bin|obj)/' })
    $extra = @($actual | Where-Object { $_ -notin $expected })
    if ($extra.Count -gt 0) { throw "Unexpected generated files: $($extra -join ', ')" }
}

$sync = Join-Path $PSScriptRoot 'Sync-IFXPolicyInputs.ps1'
if (-not $SkipAuthorityCheck) {
    & $sync -Mode $(if ($Mode -eq 'Generate') { 'Generate' } else { 'Check' }) -TargetRoot $target
}
Assert-Inputs
if ($Mode -eq 'Validate') { Write-Host 'IFX gate inputs are present and locally bound.'; exit 0 }
if ($Mode -eq 'Generate') {
    foreach ($file in Get-SourceFiles) {
        $relative = [IO.Path]::GetRelativePath($template, $file.FullName)
        $destination = Join-Path $generated $relative
        [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes($file.FullName))
    }
}
if ($Mode -in @('Generate', 'Check')) {
    Assert-Generated
    Write-Host "IFX .NET gate matches local templates: $generated"
    exit 0
}
# Byte identity with the template is owned by Check (and Generate); Test and Scan build the generated copy as it is, so a
# candidate check that overlays base-owned template tests does not fail on the overlay itself (CP07a-prep, D26).

$buildModule = @((Join-Path $packageRoot 'build/GuardBuild.psm1'), (Join-Path $packageRoot '../V3/build/GuardBuild.psm1')) |
    Where-Object { [IO.File]::Exists($_) } | Select-Object -First 1
if (-not $buildModule) { throw 'V3 build baseline (build/GuardBuild.psm1) is missing.' }
Import-Module $buildModule -Force
$packageId = [IO.Path]::GetFileName($packageRoot).ToLowerInvariant().Replace('_', '-')
$testProject = Join-Path $generated 'tests/LayerGuard.Tests/LayerGuard.Tests.csproj'

$oldAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
try {
    $nuget = $null
    if ($NuGetConfig) {
        $nuget = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($NuGetConfig)) { $NuGetConfig } else { Join-Path $target $NuGetConfig }))
        if (-not [IO.File]::Exists($nuget)) { throw "NuGet config is missing: $nuget" }
        if ($IsWindows) {
            $isolated = if ($env:GUARD_BUILD_ROOT) { Join-Path $env:GUARD_BUILD_ROOT 'nuget-appdata' } else { Join-Path $target 'artifacts/guards/v3-ifx-nuget-appdata' }
            [void] [IO.Directory]::CreateDirectory($isolated)
            $env:APPDATA = $isolated
        }
    }
    # A trusted base run (Plan 06 §11.2) places build output outside the head checkout and the base worktree.
    $buildRoot = if ($env:GUARD_BUILD_ROOT) { [IO.Path]::GetFullPath($env:GUARD_BUILD_ROOT) } else { Join-Path $target 'artifacts/build' }
    $context = New-GuardBuildContext -ArtifactsRoot (Join-Path $buildRoot "$packageId/architecture-conformance") `
        -LockRoot $(if ($LockRoot) { [IO.Path]::GetFullPath($LockRoot) } else { Join-Path $packageRoot 'build/locks' }) `
        -ReportRoot (Join-Path $target "artifacts/guards/$packageId/build/architecture-conformance") -LockMode $LockMode -NuGetConfig $nuget
    Invoke-GuardRestore $context $solution @($project, $testProject)
    if ($Mode -eq 'Test') {
        $oldFixtures = [Environment]::GetEnvironmentVariable('LAYERGUARD_FIXTURES_ROOT', 'Process')
        $oldTarget = [Environment]::GetEnvironmentVariable('GUARD_TARGET_ROOT', 'Process')
        $oldPackageRoot = [Environment]::GetEnvironmentVariable('LAYERGUARD_PACKAGE_ROOT', 'Process')
        try {
            $env:LAYERGUARD_FIXTURES_ROOT = Join-Path $generated 'tests/fixtures'
            # Policy binding tests analyze the target's src/, which is not next to a package copy run from outside it.
            $env:GUARD_TARGET_ROOT = $target
            # Binding tests read the package policy; the root is passed so the test source may move (Plan 06 P6.1).
            $env:LAYERGUARD_PACKAGE_ROOT = $packageRoot
            Invoke-GuardBuildStep $context 'test' $solution @($testProject, $project)
        }
        finally {
            [Environment]::SetEnvironmentVariable('LAYERGUARD_FIXTURES_ROOT', $oldFixtures, 'Process')
            [Environment]::SetEnvironmentVariable('GUARD_TARGET_ROOT', $oldTarget, 'Process')
            [Environment]::SetEnvironmentVariable('LAYERGUARD_PACKAGE_ROOT', $oldPackageRoot, 'Process')
        }
    }
    else { Invoke-GuardBuildStep $context 'build' $project @($project) }

    $report = if ($ReportPath) {
        if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) }
        else { [IO.Path]::GetFullPath((Join-Path $target $ReportPath)) }
    } else { Join-Path $target 'artifacts/guards/v3-ifx-layerguard.json' }
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
    Invoke-GuardDotnet $context (@('run', '--no-build', '--artifacts-path', $context.ArtifactsRoot, '--project', $project) + $context.Properties + @('--', 'check', (Join-Path $target 'src'), '--config', $policy, '--baseline', $baseline, '--format', 'json', '--report', $report, '--quiet'))
    Write-Host "IFX independent LayerGuard gate passed. Report: $report"
}
finally { [Environment]::SetEnvironmentVariable('APPDATA', $oldAppData, 'Process') }
