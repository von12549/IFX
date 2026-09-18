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
# Plan 06 P6.1 (CP07a, D26): the Architecture Conformance Gate builds, tests and scans its single source tree directly;
# the retired generated copy must not come back.
$template = Join-Path $packageRoot 'templates/ifx-layerguard'
$retiredCopy = Join-Path $packageRoot 'generated/dotnet/LayerGuard'
$policy = Join-Path $packageRoot 'policy/layerguard.json'
$baseline = Join-Path $packageRoot 'policy/baselines/plan05.json'
$solution = Join-Path $template 'LayerGuard.slnx'
$project = Join-Path $template 'src/LayerGuard/LayerGuard.csproj'
$testProject = Join-Path $template 'tests/LayerGuard.Tests/LayerGuard.Tests.csproj'
# Plan 06 P6.3 (CP07b-prep, D27): IFX policy binding tests reach the gate only through the IFX facade project, whose path
# and entry point stay the same when the binding is separated from the generic engine.
$ifxProject = Join-Path $template 'src/LayerGuard.Ifx/LayerGuard.Ifx.csproj'
$ifxTestProject = Join-Path $template 'tests/LayerGuard.Ifx.Tests/LayerGuard.Ifx.Tests.csproj'
# Every project of the solution with the exact project references it may declare; nothing is discovered by wildcard.
$projectReferences = [ordered]@{
    $project = @()
    $ifxProject = @($project)
    $testProject = @($project)
    $ifxTestProject = @($ifxProject)
}
$fixturesRoot = Join-Path $template 'tests/fixtures'

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

function Get-TemplateRelative([string] $Path) { return [IO.Path]::GetRelativePath($template, $Path).Replace('\', '/') }

function Assert-Source {
    # Check and Generate verify the single source tree instead of comparing a copy.
    if ([IO.Directory]::Exists($retiredCopy)) { throw "The retired generated LayerGuard copy exists again: $retiredCopy. Build from templates/ifx-layerguard (Plan 06 P6.1)." }
    $files = @(Get-SourceFiles | Where-Object { (Get-TemplateRelative $_.FullName) -notmatch '(^|/)(bin|obj)/' })

    # Source manifest: the solution names exactly the engine, IFX facade and test projects, each with its exact project references.
    [xml] $solutionXml = [IO.File]::ReadAllText($solution)
    $declared = @($solutionXml.SelectNodes('//Project') | ForEach-Object { ([string] $_.Path).Replace('\', '/') } | Sort-Object -Unique)
    $actual = @($files | Where-Object { $_.Extension -eq '.csproj' } | ForEach-Object { Get-TemplateRelative $_.FullName } | Where-Object { -not $_.StartsWith('tests/fixtures/', [StringComparison]::Ordinal) } | Sort-Object -Unique)
    if (($declared -join "`n") -cne ($actual -join "`n")) { throw "LayerGuard.slnx projects differ from the source tree. Declared: $($declared -join ', '); found: $($actual -join ', ')" }
    $expected = @($projectReferences.Keys | ForEach-Object { Get-TemplateRelative $_ } | Sort-Object -Unique)
    if (($declared -join "`n") -cne ($expected -join "`n")) { throw "LayerGuard.slnx projects differ from the expected project set. Declared: $($declared -join ', '); expected: $($expected -join ', ')" }
    foreach ($entry in $projectReferences.GetEnumerator()) {
        [xml] $projectXml = [IO.File]::ReadAllText($entry.Key)
        $includes = @($projectXml.SelectNodes('//ProjectReference') | ForEach-Object { ([string] $_.Include).Replace('\', '/') })
        if (@($includes | Where-Object { $_ -match '[*?]' }).Count -gt 0) { throw "$(Get-TemplateRelative $entry.Key) uses a wildcard project reference: $($includes -join ', ')" }
        $references = @($includes | ForEach-Object { Get-TemplateRelative ([IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $entry.Key) $_))) } | Sort-Object -Unique)
        $allowed = @($entry.Value | ForEach-Object { Get-TemplateRelative $_ } | Sort-Object -Unique)
        if (($references -join "`n") -cne ($allowed -join "`n")) { throw "$(Get-TemplateRelative $entry.Key) project references differ from the expected set. Found: $($references -join ', '); expected: $($allowed -join ', ')" }
    }

    # Every source file belongs to a trusted component, so no engine or test file escapes base-owned validation.
    $manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'shared/trusted-components.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    $componentPaths = @($manifest.components | Where-Object { $_.status -eq 'active' } | ForEach-Object { $_.paths })
    foreach ($file in $files) {
        $repositoryPath = 'docs/guards/V3_ifx/templates/ifx-layerguard/' + (Get-TemplateRelative $file.FullName)
        $covered = @($componentPaths | Where-Object { $repositoryPath -ceq $_ -or ($_.EndsWith('/') -and $repositoryPath.StartsWith($_, [StringComparison]::Ordinal)) }).Count -gt 0
        if (-not $covered) { throw "LayerGuard source file is outside the trusted component manifest: $repositoryPath" }
    }

    # Fixtures: every fixture the tests name exists as a project fixture, and no fixture directory is orphaned.
    $fixtureSource = [IO.File]::ReadAllText((Join-Path $template 'tests/LayerGuard.Tests/Fixtures.cs'))
    $named = @([Regex]::Matches($fixtureSource, 'public const string (\w+) = "(\w+)";') | ForEach-Object { $_.Groups[2].Value } | Sort-Object -Unique)
    if ($named.Count -eq 0) { throw 'LayerGuard.Tests names no fixtures.' }
    $directories = @(if ([IO.Directory]::Exists($fixturesRoot)) { Get-ChildItem -LiteralPath $fixturesRoot -Directory | ForEach-Object Name | Sort-Object -Unique })
    if (($named -join "`n") -cne ($directories -join "`n")) { throw "LayerGuard fixtures differ from the fixtures the tests name. Named: $($named -join ', '); found: $($directories -join ', ')" }
    foreach ($name in $named) {
        if (@(Get-ChildItem -LiteralPath (Join-Path $fixturesRoot $name) -Recurse -File | Where-Object { $_.Extension -in @('.csproj', '.slnx', '.sln') }).Count -eq 0) { throw "LayerGuard fixture has no project: $name" }
    }
}

$sync = Join-Path $PSScriptRoot 'Sync-IFXPolicyInputs.ps1'
if (-not $SkipAuthorityCheck) {
    # Generate is read-only since P6.1, so policy projections are only checked here.
    & $sync -Mode Check -TargetRoot $target
}
Assert-Inputs
if ($Mode -eq 'Validate') { Write-Host 'IFX gate inputs are present and locally bound.'; exit 0 }
Assert-Source
if ($Mode -in @('Generate', 'Check')) {
    # Generate stays callable for the active workflow during the transition, but writes nothing (D26).
    Write-Host "IFX .NET gate source verified ($Mode, read-only): $template"
    exit 0
}

$buildModule = @((Join-Path $packageRoot 'build/GuardBuild.psm1'), (Join-Path $packageRoot '../V3/build/GuardBuild.psm1')) |
    Where-Object { [IO.File]::Exists($_) } | Select-Object -First 1
if (-not $buildModule) { throw 'V3 build baseline (build/GuardBuild.psm1) is missing.' }
Import-Module $buildModule -Force
$packageId = [IO.Path]::GetFileName($packageRoot).ToLowerInvariant().Replace('_', '-')

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
    Invoke-GuardRestore $context $solution @($project, $ifxProject, $testProject, $ifxTestProject)
    if ($Mode -eq 'Test') {
        $oldFixtures = [Environment]::GetEnvironmentVariable('LAYERGUARD_FIXTURES_ROOT', 'Process')
        $oldTarget = [Environment]::GetEnvironmentVariable('GUARD_TARGET_ROOT', 'Process')
        $oldPackageRoot = [Environment]::GetEnvironmentVariable('LAYERGUARD_PACKAGE_ROOT', 'Process')
        try {
            $env:LAYERGUARD_FIXTURES_ROOT = $fixturesRoot
            # Policy binding tests analyze the target's src/, which is not next to a package copy run from outside it.
            $env:GUARD_TARGET_ROOT = $target
            # Binding tests read the package policy; the root is passed so the test source may move (Plan 06 P6.1).
            $env:LAYERGUARD_PACKAGE_ROOT = $packageRoot
            Invoke-GuardBuildStep $context 'test' $solution @($testProject, $project, $ifxProject, $ifxTestProject)
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
