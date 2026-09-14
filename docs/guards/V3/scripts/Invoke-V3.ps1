[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate', 'Pre', 'Generate', 'Check', 'Test', 'Diff')][string] $Mode,
    [Parameter(Mandatory)][string] $ProfileDirectory,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $OutputDirectory,
    [string] $PlanPath,
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
        if ($rule.kind -ne 'none') {
            [void] (Assert-SafeRelativePath $rule.sourcePattern -AllowGlob)
            [void] (Assert-SafeRelativePath $rule.forbiddenTargetPattern -AllowGlob)
            [void] (Assert-SafeRelativePath $rule.negativeFixture.sourceProject)
            $reference = [string] $rule.negativeFixture.referenceInclude
            if ([IO.Path]::IsPathRooted($reference) -or $reference -match '^[A-Za-z]:' -or $reference -match '[*?]') { throw "Invalid negative fixture reference: $reference" }
        }
        $rules += $rule
    }
    $risks = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($risk in $profile.riskTriggers) {
        if (-not $risks.Add($risk.id)) { throw "Duplicate risk ID: $($risk.id)" }
        [void] (Assert-SafeRelativePath $risk.pathPattern -AllowGlob)
    }
    return [ordered]@{ Profile = $profile; Tech = $tech; Rules = $rules; RuleFiles = $ruleFiles }
}

function Get-Plan {
    param([object] $Data)
    if (-not $PlanPath) { throw 'PlanPath is required.' }
    $planFile = if ([IO.Path]::IsPathRooted($PlanPath)) { [IO.Path]::GetFullPath($PlanPath) } else { Resolve-TargetPath $PlanPath -MustExist }
    if (-not $planFile.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'PlanPath must be under TargetRoot.' }
    if (-not $planFile.EndsWith('.plan.json', [StringComparison]::Ordinal)) { throw 'PlanPath must end in .plan.json.' }
    $plan = Read-ValidatedJson $planFile 'plan'
    if ([IO.Path]::GetFileName($planFile) -cne "$($plan.id).plan.json") { throw 'Plan ID must match file name.' }
    $companion = $planFile.Substring(0, $planFile.Length - '.plan.json'.Length) + '.md'
    if (-not [IO.File]::Exists($companion)) { throw "Missing Markdown Plan companion: $companion" }
    $ruleIds = @($Data.Rules | ForEach-Object { $_.id })
    foreach ($id in $plan.ruleIds) { if ($id -notin $ruleIds) { throw "Unknown Plan rule ID: $id" } }
    foreach ($path in $plan.plannedPaths) {
        $safe = Assert-SafeRelativePath $path
        foreach ($rule in $Data.Rules) {
            if ($rule.kind -ne 'none' -and (Test-Glob $safe $rule.sourcePattern) -and $rule.id -notin $plan.ruleIds) { throw "Plan omits applicable rule $($rule.id) for $safe" }
        }
    }
    foreach ($decision in $plan.decisionPaths) {
        $file = Resolve-TargetPath $decision -MustExist
        $record = Read-ValidatedJson $file 'decision'
        foreach ($pattern in $record.affectedPaths) { [void] (Assert-SafeRelativePath $pattern -AllowGlob) }
    }
    foreach ($path in $plan.plannedPaths) {
        foreach ($risk in $Data.Profile.riskTriggers) {
            if (-not (Test-Glob $path $risk.pathPattern)) { continue }
            $covered = $false
            foreach ($decision in $plan.decisionPaths) {
                $record = Read-ValidatedJson (Resolve-TargetPath $decision -MustExist) 'decision'
                if (@($record.affectedPaths | Where-Object { Test-Glob $path $_ }).Count -gt 0) { $covered = $true; break }
            }
            if (-not $covered) { throw "Risk $($risk.id) requires a decision covering $path" }
        }
    }
    return [ordered]@{ Document = $plan; Path = $planFile }
}

function ConvertTo-Lf {
    param([string] $Value)
    return $Value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n"
}

function Get-ExpectedFiles {
    param([object] $Data)
    $files = [ordered]@{}
    $project = Get-Content -LiteralPath (Join-Path $packageRoot 'templates/dotnet/GuardV3.Tests.csproj.in') -Raw
    $files['GuardV3.Tests.csproj'] = ConvertTo-Lf ($project.Replace('__TARGET_FRAMEWORK__', $Data.Tech.testProject.targetFramework))
    $files['GuardTests.cs'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $packageRoot 'templates/dotnet/GuardTests.cs.in') -Raw)
    $files['profile.json'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $profileRoot 'profile.json') -Raw)
    $files['tech-stack.json'] = ConvertTo-Lf (Get-Content -LiteralPath (Join-Path $profileRoot 'tech-stack.json') -Raw)
    foreach ($file in $Data.RuleFiles) { $files["rules/$($file.Name)"] = ConvertTo-Lf (Get-Content -LiteralPath $file.FullName -Raw) }
    return $files
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
    $oldAppData = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    try {
        $env:GUARD_TARGET_ROOT = $root
        $env:GUARD_GENERATED_ROOT = $output
        if ($PlanFile) { $env:GUARD_PLAN_PATH = $PlanFile; $env:GUARD_BASE_REF = $BaseRef; $env:GUARD_HEAD_REF = $HeadRef }
        $project = Join-Path $output 'GuardV3.Tests.csproj'
        if ($NuGetConfig) {
            $configPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($NuGetConfig)) { $NuGetConfig } else { Join-Path $root $NuGetConfig }))
            if (-not [IO.File]::Exists($configPath)) { throw "NuGetConfig is missing: $configPath" }
            if ($IsWindows) {
                $isolatedAppData = Join-Path $root 'artifacts/guards/v3-nuget-appdata'
                [void] [IO.Directory]::CreateDirectory($isolatedAppData)
                $env:APPDATA = $isolatedAppData
            }
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
        [Environment]::SetEnvironmentVariable('APPDATA', $oldAppData, 'Process')
    }
}

$data = Get-Profile
if ($Mode -eq 'Validate') { Write-Host "V3 profile valid: $($data.Profile.projectId)"; exit 0 }
if ($Mode -eq 'Pre') {
    $plan = Get-Plan $data
    Write-Host "V3 Pre advisory: Plan $($plan.Document.id) has valid structure and risk association; future code is unverified."
    exit 0
}
$expected = Get-ExpectedFiles $data
if ($Mode -eq 'Generate') {
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
