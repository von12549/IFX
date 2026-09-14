[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate', 'Pre', 'Generate', 'Check', 'Test', 'Diff')][string] $Mode,
    [Parameter(Mandatory)][string] $ProfileDirectory,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $OutputDirectory,
    [string] $PlanPath,
    [string[]] $PlannedPaths = @(),
    [string] $ReportPath,
    [string] $BaseRef,
    [string] $HeadRef,
    [string] $NuGetConfig
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
$profileRoot = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ProfileDirectory)) { $ProfileDirectory } else { Join-Path $root $ProfileDirectory }))
if (-not [IO.Directory]::Exists($profileRoot)) { throw "ProfileDirectory does not exist: $profileRoot" }
$output = [IO.Path]::GetFullPath($(if ($OutputDirectory) {
    if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
} else { Join-Path $packageRoot 'generated/dotnet' }))
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must stay under TargetRoot.' }

function Assert-SafeRelativePath {
    param([string] $Value, [switch] $AllowGlob)
    $normalized = $Value.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or
        @($normalized -split '/' | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0 -or $normalized -eq '**') {
        throw "Unsafe repository-relative path or pattern: $Value"
    }
    if (-not $AllowGlob -and $normalized -match '[*?]') { throw "Expected an exact path: $Value" }
    return $normalized
}

function Resolve-TargetPath {
    param([string] $Relative, [switch] $MustExist)
    $safe = Assert-SafeRelativePath $Relative
    $full = [IO.Path]::GetFullPath((Join-Path $root $safe))
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes TargetRoot: $Relative" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full)) { throw "Missing path: $Relative" }
    return $full
}

function Test-Glob {
    param([string] $Path, [string] $Pattern)
    $patternText = $Pattern.Replace('\', '/')
    $regex = [Text.StringBuilder]::new('^')
    for ($i = 0; $i -lt $patternText.Length; $i++) {
        if ($i + 2 -lt $patternText.Length -and $patternText.Substring($i, 3) -eq '**/') {
            [void] $regex.Append('(?:.*/)?'); $i += 2
        }
        elseif ($i + 1 -lt $patternText.Length -and $patternText.Substring($i, 2) -eq '**') {
            [void] $regex.Append('.*'); $i++
        }
        elseif ($patternText[$i] -eq '*') { [void] $regex.Append('[^/]*') }
        elseif ($patternText[$i] -eq '?') { [void] $regex.Append('[^/]') }
        else { [void] $regex.Append([Regex]::Escape([string] $patternText[$i])) }
    }
    [void] $regex.Append('$')
    return [Regex]::IsMatch($Path.Replace('\', '/'), $regex.ToString(), [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Read-ValidatedJson {
    param([string] $Path, [string] $SchemaName)
    $schema = Join-Path $packageRoot "contracts/$SchemaName.schema.json"
    if (-not (Test-Json -Path $Path -SchemaFile $schema -ErrorAction Stop)) { throw "Invalid $SchemaName JSON: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Profile {
    $profile = Read-ValidatedJson (Join-Path $profileRoot 'profile.json') 'profile'
    $map = Read-ValidatedJson (Join-Path $profileRoot 'project-map.json') 'project-map'
    $tech = Read-ValidatedJson (Join-Path $profileRoot 'tech-stack.json') 'tech-stack'
    $ruleRoot = Join-Path $profileRoot 'rules'
    if (-not [IO.Directory]::Exists($ruleRoot)) { throw "Missing rules directory: $ruleRoot" }
    $ruleFiles = @(Get-ChildItem -LiteralPath $ruleRoot -File -Filter '*.json' | Sort-Object Name)
    if ($ruleFiles.Count -eq 0) { throw 'At least one rule is required.' }
    $rules = @()
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $ruleFiles) {
        $rule = Read-ValidatedJson $file.FullName 'rule'
        if ($file.BaseName -cne $rule.id) { throw "Rule ID must match file name: $($file.Name)" }
        if (-not $ids.Add($rule.id)) { throw "Duplicate rule ID: $($rule.id)" }
        foreach ($pattern in $rule.appliesTo) { [void] (Assert-SafeRelativePath $pattern -AllowGlob) }
        if ($rule.kind -eq 'forbidden-project-reference') {
            [void] (Assert-SafeRelativePath $rule.sourcePattern -AllowGlob)
            [void] (Assert-SafeRelativePath $rule.forbiddenTargetPattern -AllowGlob)
            [void] (Assert-SafeRelativePath $rule.negativeFixture.sourceProject)
            $reference = [string] $rule.negativeFixture.referenceInclude
            if ([IO.Path]::IsPathRooted($reference) -or $reference -match '^[A-Za-z]:' -or $reference -match '[*?]') { throw "Invalid negative fixture reference: $reference" }
        }
        elseif ($rule.kind -eq 'forbidden-type-dependency') {
            foreach ($name in @($rule.sourceAssembly, $rule.forbiddenAssembly)) {
                if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_.-]*$') { throw "Invalid assembly name in $($rule.id): $name" }
            }
            foreach ($name in @($rule.sourceNamespace, $rule.forbiddenNamespace)) {
                if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') { throw "Invalid namespace in $($rule.id): $name" }
            }
        }
        elseif ($rule.kind -eq 'interface-implementation-location') {
            foreach ($name in @($rule.interfaceAssembly, $rule.implementationAssembly)) {
                if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_.-]*$') { throw "Invalid assembly name in $($rule.id): $name" }
            }
            foreach ($name in @($rule.interfaceType, $rule.implementationNamespace)) {
                if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_.]*$') { throw "Invalid type or namespace in $($rule.id): $name" }
            }
        }
        $rules += $rule
    }
    $assemblyRules = @($rules | Where-Object { $_.kind -in @('forbidden-type-dependency', 'interface-implementation-location') })
    if ($assemblyRules.Count -gt 0 -and -not $tech.Contains('assemblyGate')) { throw 'Assembly rules require tech-stack.json assemblyGate.' }
    if ($assemblyRules.Count -eq 0 -and $tech.Contains('assemblyGate')) { throw 'assemblyGate requires at least one assembly rule.' }
    if ($assemblyRules.Count -gt 0) {
        [void] (Resolve-TargetPath $tech.assemblyGate.buildTarget -MustExist)
        if ($tech.assemblyGate.buildTarget -notmatch '\.(sln|slnx|csproj)$') { throw 'assemblyGate.buildTarget must be a solution or .csproj.' }
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $tech.assemblyGate.assemblies) {
            [void] (Resolve-TargetPath $entry.projectPath -MustExist)
            if (-not $entry.projectPath.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) { throw "Expected a .csproj assembly source: $($entry.projectPath)" }
            [void] (Assert-SafeRelativePath $entry.assemblyPath)
            $projectFolder = [IO.Path]::GetDirectoryName($entry.projectPath.Replace('\', '/')).Replace('\', '/')
            if (-not $entry.assemblyPath.Replace('\', '/').StartsWith("$projectFolder/bin/Debug/", [StringComparison]::OrdinalIgnoreCase)) { throw "Assembly path is outside its project's Debug output: $($entry.assemblyPath)" }
            if ($entry.assemblyPath -notmatch '/bin/Debug/' -or -not $entry.assemblyPath.EndsWith("/$($entry.assemblyName).dll", [StringComparison]::OrdinalIgnoreCase)) {
                throw "Assembly path must name the Debug DLL for $($entry.assemblyName): $($entry.assemblyPath)"
            }
            if (-not $names.Add($entry.assemblyName) -or -not $paths.Add($entry.assemblyPath)) { throw "Duplicate assembly manifest entry: $($entry.assemblyName)" }
        }
        foreach ($rule in $assemblyRules) {
            $required = if ($rule.kind -eq 'forbidden-type-dependency') { @($rule.sourceAssembly, $rule.forbiddenAssembly) } else { @($rule.interfaceAssembly, $rule.implementationAssembly) }
            foreach ($name in $required) { if (-not $names.Contains($name)) { throw "Rule $($rule.id) uses undeclared assembly: $name" } }
        }
    }
    $commands = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($command in $tech.commands) {
        if (-not $commands.Add($command.id)) { throw "Duplicate command ID: $($command.id)" }
        if ($command.workingDirectory -ne '.') { [void] (Assert-SafeRelativePath $command.workingDirectory) }
    }
    $areas = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($area in $map.areas) {
        if (-not $areas.Add($area.id)) { throw "Duplicate area ID: $($area.id)" }
        [void] (Assert-SafeRelativePath $area.pathPattern -AllowGlob)
        [void] (Assert-SafeRelativePath $area.similarImplementationRoot)
        foreach ($commandId in $area.focusedCommands) {
            if (-not $commands.Contains($commandId)) { throw "Area $($area.id) names unknown command ID: $commandId" }
        }
    }
    $risks = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($risk in $map.riskTriggers) {
        if (-not $risks.Add($risk.id)) { throw "Duplicate risk ID: $($risk.id)" }
        [void] (Assert-SafeRelativePath $risk.pathPattern -AllowGlob)
    }
    return [ordered]@{ Profile = $profile; Map = $map; Tech = $tech; Rules = $rules; RuleFiles = $ruleFiles }
}

function Get-Impact {
    param([object] $Data, [string[]] $Paths)
    $safePaths = @($Paths | ForEach-Object { Assert-SafeRelativePath $_ } | Sort-Object -Unique)
    if ($safePaths.Count -eq 0) { throw 'Pre requires at least one planned path.' }
    $selectedByPath = @{}
    foreach ($path in $safePaths) {
        $matches = @($Data.Map.areas | Where-Object { Test-Glob $path $_.pathPattern } | Sort-Object { $_.pathPattern.Length } -Descending)
        if ($matches.Count -gt 0) { $selectedByPath[$path] = $matches[0].id }
    }
    $areas = @($Data.Map.areas | ForEach-Object {
        $area = $_
        $matches = @($safePaths | Where-Object { $selectedByPath[$_] -eq $area.id })
        if ($matches.Count -gt 0) {
            [ordered]@{
                id = $area.id; layer = $area.layer; owner = $area.owner
                similarImplementationRoot = $area.similarImplementationRoot
                focusedCommands = @($area.focusedCommands); paths = $matches
            }
        }
    })
    $unmapped = @($safePaths | Where-Object { -not $selectedByPath.ContainsKey($_) })
    $risks = @($Data.Map.riskTriggers | ForEach-Object {
        $risk = $_
        $matches = @($safePaths | Where-Object { Test-Glob $_ $risk.pathPattern })
        if ($matches.Count -gt 0) { [ordered]@{ id = $risk.id; reason = $risk.reason; paths = $matches } }
    })
    $rules = @($Data.Rules | Where-Object {
        $rule = $_
        @($safePaths | Where-Object {
            $path = $_
            @($rule.appliesTo | Where-Object { Test-Glob $path $_ }).Count -gt 0
        }).Count -gt 0
    } | ForEach-Object { $_.id } | Sort-Object -Unique)
    $suggested = @($areas | ForEach-Object { $_.focusedCommands } | Sort-Object -Unique)
    return [ordered]@{ Paths = $safePaths; Areas = $areas; Unmapped = $unmapped; Risks = $risks; Rules = $rules; Commands = $suggested }
}

function Get-Plan {
    param([object] $Data)
    if (-not $PlanPath) { throw 'PlanPath is required.' }
    $planFile = if ([IO.Path]::IsPathRooted($PlanPath)) { [IO.Path]::GetFullPath($PlanPath) } else { Resolve-TargetPath $PlanPath -MustExist }
    if (-not $planFile.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be under TargetRoot.' }
    if (-not $planFile.EndsWith('.plan.json', [StringComparison]::Ordinal)) { throw 'PlanPath must end in .plan.json.' }
    $plan = Read-ValidatedJson $planFile 'plan'
    if ([IO.Path]::GetFileName($planFile) -cne "$($plan.id).plan.json") { throw 'Plan ID must match file name.' }
    if ([string]::IsNullOrWhiteSpace($plan.goal) -or @($plan.acceptanceCriteria | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw 'Plan goal and acceptance criteria must contain non-whitespace text.'
    }
    $companion = $planFile.Substring(0, $planFile.Length - '.plan.json'.Length) + '.md'
    if (-not [IO.File]::Exists($companion)) { throw "Missing Markdown Plan companion: $companion" }
    if ([string]::IsNullOrWhiteSpace([IO.File]::ReadAllText($companion))) { throw 'Markdown Plan companion is empty.' }
    $impact = Get-Impact $Data @($plan.plannedPaths)
    if ($impact.Unmapped.Count -gt 0) { throw "Unmapped Plan paths: $($impact.Unmapped -join ', ')" }
    $areaIds = @($Data.Map.areas | ForEach-Object { $_.id })
    foreach ($id in $plan.areaIds) { if ($id -notin $areaIds) { throw "Unknown Plan area ID: $id" } }
    foreach ($id in @($impact.Areas | ForEach-Object { $_.id })) {
        if ($id -notin $plan.areaIds) { throw "Plan omits affected area $id" }
    }
    $ruleIds = @($Data.Rules | ForEach-Object { $_.id })
    foreach ($id in $plan.ruleIds) { if ($id -notin $ruleIds) { throw "Unknown Plan rule ID: $id" } }
    foreach ($id in $impact.Rules) { if ($id -notin $plan.ruleIds) { throw "Plan omits applicable rule $id" } }
    $commandIds = @($Data.Tech.commands | ForEach-Object { $_.id })
    foreach ($id in $plan.validationCommands) { if ($id -notin $commandIds) { throw "Unknown Plan validation command: $id" } }
    foreach ($id in $impact.Commands) { if ($id -notin $plan.validationCommands) { throw "Plan omits focused validation command $id" } }
    foreach ($decision in $plan.decisionPaths) {
        $file = Resolve-TargetPath $decision -MustExist
        $record = Read-ValidatedJson $file 'decision'
        foreach ($pattern in $record.affectedPaths) { [void] (Assert-SafeRelativePath $pattern -AllowGlob) }
    }
    foreach ($path in $plan.plannedPaths) {
        foreach ($risk in $Data.Map.riskTriggers) {
            if (-not (Test-Glob $path $risk.pathPattern)) { continue }
            $covered = $false
            foreach ($decision in $plan.decisionPaths) {
                $record = Read-ValidatedJson (Resolve-TargetPath $decision -MustExist) 'decision'
                if (@($record.affectedPaths | Where-Object { Test-Glob $path $_ }).Count -gt 0) { $covered = $true; break }
            }
            if (-not $covered) { throw "Risk $($risk.id) requires a decision covering $path" }
        }
    }
    return [ordered]@{ Document = $plan; Path = $planFile; Impact = $impact }
}

function ConvertTo-Lf {
    param([string] $Value)
    return $Value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n"
}

function Get-ExpectedFiles {
    param([object] $Data)
    $files = [ordered]@{}
    $project = Get-Content -LiteralPath (Join-Path $packageRoot 'templates/dotnet/GuardV3.Tests.csproj.in') -Raw
    $hasAssemblies = @($Data.Rules | Where-Object { $_.kind -in @('forbidden-type-dependency', 'interface-implementation-location') }).Count -gt 0
    $packageReference = if ($hasAssemblies) { '    <PackageReference Include="TngTech.ArchUnitNET" Version="0.13.4" />' } else { '' }
    $files['GuardV3.Tests.csproj'] = ConvertTo-Lf ($project.Replace('__TARGET_FRAMEWORK__', $Data.Tech.testProject.targetFramework).Replace('__ARCHUNIT_PACKAGE_REFERENCE__', $packageReference))
    $files['GuardTests.cs'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $packageRoot 'templates/dotnet/GuardTests.cs.in') -Raw)
    if ($hasAssemblies) { $files['AssemblyGuardTests.cs'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $packageRoot 'templates/dotnet/AssemblyGuardTests.cs.in') -Raw) }
    $files['profile.json'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $profileRoot 'profile.json') -Raw)
    $files['project-map.json'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $profileRoot 'project-map.json') -Raw)
    $files['tech-stack.json'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $profileRoot 'tech-stack.json') -Raw)
    foreach ($file in $Data.RuleFiles) { $files["rules/$($file.Name)"] = ConvertTo-Lf (Get-Content -LiteralPath $file.FullName -Raw) }
    return $files
}

function Get-InputHash {
    param([object] $Data)
    $names = @('profile.json', 'project-map.json', 'tech-stack.json') + @($Data.RuleFiles | ForEach-Object { "rules/$($_.Name)" })
    $builder = [Text.StringBuilder]::new()
    foreach ($name in $names) {
        $path = Join-Path $profileRoot $name
        [void] $builder.Append($name).Append("`n").Append((ConvertTo-Lf ([IO.File]::ReadAllText($path))))
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($builder.ToString())
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Assert-GeneratedFiles {
    param([object] $Expected)
    if (-not [IO.Directory]::Exists($output)) { throw "Generated project is missing: $output" }
    foreach ($name in $Expected.Keys) {
        $file = Join-Path $output $name
        if (-not [IO.File]::Exists($file)) { throw "Generated file is missing: $name" }
        $expectedBytes = [Text.UTF8Encoding]::new($false).GetBytes($Expected[$name])
        $actualBytes = [IO.File]::ReadAllBytes($file)
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $actualBytes, [byte[]] $expectedBytes)) { throw "Generated file drift: $name" }
    }
    $actual = @(Get-ChildItem -LiteralPath $output -File -Recurse | ForEach-Object {
        [IO.Path]::GetRelativePath($output, $_.FullName).Replace('\', '/')
    } | Where-Object { $_ -notmatch '^(bin|obj)/' })
    $extra = @($actual | Where-Object { $_ -notin @($Expected.Keys) })
    if ($extra.Count -gt 0) { throw "Unexpected generated files: $($extra -join ', ')" }
}

function Invoke-DotnetTests {
    param([string] $Filter, [string] $PlanFile)
    $oldRoot = [Environment]::GetEnvironmentVariable('GUARD_TARGET_ROOT', 'Process')
    $oldPlan = [Environment]::GetEnvironmentVariable('GUARD_PLAN_PATH', 'Process')
    $oldBase = [Environment]::GetEnvironmentVariable('GUARD_BASE_REF', 'Process')
    $oldHead = [Environment]::GetEnvironmentVariable('GUARD_HEAD_REF', 'Process')
    $oldGenerated = [Environment]::GetEnvironmentVariable('GUARD_GENERATED_ROOT', 'Process')
    $oldInputHash = [Environment]::GetEnvironmentVariable('GUARD_INPUT_SHA256', 'Process')
    $oldAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    try {
        $env:GUARD_TARGET_ROOT = $root
        $env:GUARD_GENERATED_ROOT = $output
        $env:GUARD_INPUT_SHA256 = Get-InputHash $data
        if ($PlanFile) { $env:GUARD_PLAN_PATH = $PlanFile; $env:GUARD_BASE_REF = $BaseRef; $env:GUARD_HEAD_REF = $HeadRef }
        $project = Join-Path $output 'GuardV3.Tests.csproj'
        $configPath = $null
        if ($NuGetConfig) {
            $configPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($NuGetConfig)) { $NuGetConfig } else { Join-Path $root $NuGetConfig }))
            if (-not [IO.File]::Exists($configPath)) { throw "NuGetConfig is missing: $configPath" }
            if ($IsWindows) {
                $isolatedAppData = Join-Path $root 'artifacts/guards/v3-nuget-appdata'
                [void] [IO.Directory]::CreateDirectory($isolatedAppData)
                $env:APPDATA = $isolatedAppData
            }
        }
        if ($Filter -ne 'Stage=Diff' -and $data.Tech.Contains('assemblyGate')) {
            $gate = $data.Tech.assemblyGate
            $buildStarted = [DateTime]::UtcNow
            $build = Resolve-TargetPath $gate.buildTarget -MustExist
            if ($configPath) { & dotnet restore $build --configfile $configPath --nologo; if ($LASTEXITCODE -ne 0) { throw 'Target restore failed.' } }
            $buildOptions = if ($configPath) { @('--no-restore') } else { @() }
            & dotnet build $build --configuration Debug --no-incremental --nologo @buildOptions
            if ($LASTEXITCODE -ne 0) { throw "Target Debug build failed with exit code $LASTEXITCODE" }
            foreach ($entry in $gate.assemblies) {
                $targetProject = Resolve-TargetPath $entry.projectPath -MustExist
                if ($configPath) { & dotnet restore $targetProject --configfile $configPath --nologo; if ($LASTEXITCODE -ne 0) { throw "Assembly project restore failed: $($entry.projectPath)" } }
                & dotnet build $targetProject --configuration Debug --no-incremental --nologo @buildOptions
                if ($LASTEXITCODE -ne 0) { throw "Assembly project build failed: $($entry.projectPath)" }
                $dll = Resolve-TargetPath $entry.assemblyPath -MustExist
                if ([IO.File]::GetLastWriteTimeUtc($dll) -lt $buildStarted.AddSeconds(-2)) { throw "Assembly was not refreshed by the Debug build: $($entry.assemblyPath)" }
                $actual = [Reflection.AssemblyName]::GetAssemblyName($dll).Name
                if ($actual -cne $entry.assemblyName) { throw "Assembly identity mismatch: $($entry.assemblyPath) is $actual" }
            }
        }
        if ($configPath) {
            & dotnet restore $project --configfile $configPath --nologo
            if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed with exit code $LASTEXITCODE" }
            & dotnet test $project --no-restore --filter $Filter --nologo
        }
        else { & dotnet test $project --filter $Filter --nologo }
        if ($LASTEXITCODE -ne 0) { throw "dotnet test failed with exit code $LASTEXITCODE" }
    }
    finally {
        [Environment]::SetEnvironmentVariable('GUARD_TARGET_ROOT', $oldRoot, 'Process')
        [Environment]::SetEnvironmentVariable('GUARD_PLAN_PATH', $oldPlan, 'Process')
        [Environment]::SetEnvironmentVariable('GUARD_BASE_REF', $oldBase, 'Process')
        [Environment]::SetEnvironmentVariable('GUARD_HEAD_REF', $oldHead, 'Process')
        [Environment]::SetEnvironmentVariable('GUARD_GENERATED_ROOT', $oldGenerated, 'Process')
        [Environment]::SetEnvironmentVariable('GUARD_INPUT_SHA256', $oldInputHash, 'Process')
        [Environment]::SetEnvironmentVariable('APPDATA', $oldAppData, 'Process')
    }
}

if ($Mode -eq 'Pre') {
    $reportRelative = if ($ReportPath) { Assert-SafeRelativePath $ReportPath } else { 'artifacts/guards/v3-pre.json' }
    $reportFile = Resolve-TargetPath $reportRelative
    $report = [ordered]@{
        formatVersion = 1; stage = 'pre'; status = 'blocked'
        mode = $(if ($PlanPath) { 'formal' } else { 'summary' })
        projectId = ''; plannedPaths = @(); planId = ''; areas = @(); unmappedPaths = @()
        risks = @(); ruleIds = @(); validationCommands = @(); inputSha256 = ''; reason = ''
    }
    try {
        if ($PlanPath -and $PlannedPaths.Count -gt 0) { throw 'Use PlanPath or PlannedPaths, not both.' }
        $data = Get-Profile
        $report.projectId = $data.Profile.projectId
        $report.inputSha256 = Get-InputHash $data
        if ($PlanPath) {
            $draftPath = if ([IO.Path]::IsPathRooted($PlanPath)) { [IO.Path]::GetFullPath($PlanPath) } else { Resolve-TargetPath $PlanPath -MustExist }
            if (-not $draftPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be under TargetRoot.' }
            $draft = Read-ValidatedJson $draftPath 'plan'
            $impact = Get-Impact $data @($draft.plannedPaths)
            $report.planId = $draft.id
            $report.validationCommands = @($draft.validationCommands)
            $report.plannedPaths = @($impact.Paths)
            $report.areas = @($impact.Areas)
            $report.unmappedPaths = @($impact.Unmapped)
            $report.risks = @($impact.Risks)
            $report.ruleIds = @($impact.Rules)
            $plan = Get-Plan $data
        }
        else {
            $impact = Get-Impact $data $PlannedPaths
            $report.plannedPaths = @($impact.Paths)
            $report.areas = @($impact.Areas)
            $report.unmappedPaths = @($impact.Unmapped)
            $report.risks = @($impact.Risks)
            $report.ruleIds = @($impact.Rules)
            $report.validationCommands = @($impact.Commands)
            if ($impact.Unmapped.Count -gt 0) { throw "Unmapped planned paths: $($impact.Unmapped -join ', ')" }
            if ($impact.Risks.Count -gt 0) { throw 'Risk-triggered paths require a formal Plan and covering decision.' }
        }
        $report.status = 'advisory'
        $report.reason = 'Pre inputs are valid; future code remains unverified.'
    }
    catch {
        $report.reason = $_.Exception.Message
    }
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($reportFile))
    $reportJson = ConvertTo-Json -InputObject $report -Depth 100
    [IO.File]::WriteAllText($reportFile, $reportJson + "`n", [Text.UTF8Encoding]::new($false))
    if (-not (Test-Json -Path $reportFile -SchemaFile (Join-Path $packageRoot 'contracts/pre-result.schema.json') -ErrorAction Stop)) { throw 'Pre report does not match its schema.' }
    Write-Host "V3 Pre $($report.status): $($report.reason) Report: $reportFile"
    if ($report.status -eq 'blocked') { exit 1 }
    exit 0
}
$data = Get-Profile
if ($Mode -eq 'Validate') { Write-Host "V3 profile valid: $($data.Profile.projectId)"; exit 0 }
$expected = Get-ExpectedFiles $data
if ($Mode -eq 'Generate') {
    $optionalAssemblyTest = Join-Path $output 'AssemblyGuardTests.cs'
    if (-not $expected.Contains('AssemblyGuardTests.cs') -and [IO.File]::Exists($optionalAssemblyTest)) {
        $resolved = [IO.Path]::GetFullPath($optionalAssemblyTest)
        if (-not $resolved.StartsWith($output.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe generated-file cleanup path.' }
        Remove-Item -LiteralPath $resolved -Force
    }
    $generatedRules = Join-Path $output 'rules'
    if ([IO.Directory]::Exists($generatedRules)) {
        foreach ($stale in @(Get-ChildItem -LiteralPath $generatedRules -File -Filter '*.json')) {
            $relative = "rules/$($stale.Name)"
            if (-not $expected.Contains($relative)) {
                $resolved = [IO.Path]::GetFullPath($stale.FullName)
                if (-not $resolved.StartsWith([IO.Path]::GetFullPath($generatedRules).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe generated-rule cleanup path.' }
                Remove-Item -LiteralPath $resolved -Force
            }
        }
    }
    foreach ($name in $expected.Keys) {
        $file = Join-Path $output $name
        [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file))
        [IO.File]::WriteAllText($file, $expected[$name], [Text.UTF8Encoding]::new($false))
    }
    Assert-GeneratedFiles $expected
    Write-Host "V3 generated .NET test project: $output"
    exit 0
}
Assert-GeneratedFiles $expected
if ($Mode -eq 'Check') { Write-Host 'V3 generated project matches profile and templates.'; exit 0 }
if ($Mode -eq 'Test') { Invoke-DotnetTests 'Stage!=Diff' ''; Write-Host 'V3 Post and detector self-tests passed.'; exit 0 }
if (-not $BaseRef) { throw 'Diff requires BaseRef.' }
$plan = Get-Plan $data
Invoke-DotnetTests 'Stage=Diff' $plan.Path
Write-Host 'V3 Diff matched declared Plan paths.'
