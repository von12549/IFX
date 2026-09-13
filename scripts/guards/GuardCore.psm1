Set-StrictMode -Version Latest

function Get-GuardRoot {
    param([string] $RepositoryRoot)
    $candidate = if ($RepositoryRoot) { $RepositoryRoot } else { Join-Path $PSScriptRoot '../..' }
    $root = [IO.Path]::GetFullPath($candidate)
    if (-not [IO.Directory]::Exists($root)) { throw "Repository root does not exist: $root" }
    return $root
}

function Resolve-GuardPath {
    param([string] $Root, [string] $Relative, [switch] $MustExist)
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '^[A-Za-z]:') {
        throw "Guard path must be repository-relative: $Relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root ($Relative.Replace('/', [IO.Path]::DirectorySeparatorChar))))
    $prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full -ne $Root -and -not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Guard path escapes the repository: $Relative"
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $full)) { throw "Guard path is missing: $Relative" }
    return $full
}

function Read-GuardDocument {
    param([string] $Root, [string] $Relative, [string] $Schema)
    $path = Resolve-GuardPath $Root $Relative -MustExist
    $schemaPath = Resolve-GuardPath $Root $Schema -MustExist
    if (-not (Test-Json -Path $path -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Guard schema validation failed: $Relative"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-UniqueIds {
    param([object[]] $Items, [string] $Label)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        if (-not $seen.Add([string] $item.id)) { throw "Duplicate $Label id: $($item.id)" }
    }
}

function Assert-GuardPattern {
    param([string] $Pattern)
    $normalized = $Pattern.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or @($normalized -split '/' | Where-Object { $_ -eq '..' -or $_ -eq '.' -or $_ -eq '' }).Count -gt 0) {
        throw "Invalid repository-relative glob: $Pattern"
    }
}

function Get-GuardData {
    param([string] $RepositoryRoot, [string] $Profile = 'ifx')
    $root = Get-GuardRoot $RepositoryRoot
    $techPath = 'docs/guards/inputs/TECH_STACK.json'
    $mapPath = 'docs/guards/inputs/PROJECT_MAP.json'
    if ($Profile -notmatch '^[a-z][a-z0-9-]*$') { throw "Invalid guard profile: $Profile" }
    $bindingPath = "docs/guards/bindings/$Profile.json"
    $tech = Read-GuardDocument $root $techPath 'docs/guards/contracts/tech-stack.schema.json'
    $map = Read-GuardDocument $root $mapPath 'docs/guards/contracts/project-map.schema.json'
    $binding = Read-GuardDocument $root $bindingPath 'docs/guards/contracts/binding.schema.json'
    $ruleDirectory = Resolve-GuardPath $root 'docs/guards/inputs/rules' -MustExist
    $ruleFiles = @(Get-ChildItem -LiteralPath $ruleDirectory -File -Filter '*.json' | Sort-Object Name)
    if ($ruleFiles.Count -eq 0) { throw 'No guard rule files were found.' }
    $rules = @()
    foreach ($file in $ruleFiles) {
        $relative = 'docs/guards/inputs/rules/' + $file.Name
        $rule = Read-GuardDocument $root $relative 'docs/guards/contracts/rule.schema.json'
        if ($file.BaseName -cne $rule.id) { throw "Rule id $($rule.id) must match its file name $($file.Name)." }
        $rules += $rule
    }
    Assert-UniqueIds $tech.commands 'command'
    Assert-UniqueIds $map.areas 'area'
    Assert-UniqueIds $map.riskTriggers 'risk trigger'
    Assert-UniqueIds $binding.detectors 'detector'
    Assert-UniqueIds $rules 'rule'
    $commandIds = @($tech.commands | ForEach-Object { [string] $_.id })
    $detectorIds = @($binding.detectors | ForEach-Object { [string] $_.id })
    $riskIds = @($map.riskTriggers | ForEach-Object { [string] $_.id })
    foreach ($command in $tech.commands) {
        $workingDirectory = Resolve-GuardPath $root ([string] $command.workingDirectory) -MustExist
        if ([string]::IsNullOrWhiteSpace($command.executable) -or $command.executable -match '[/\\]') {
            throw "Command $($command.id) needs a bare executable name."
        }
        if ($command.ContainsKey('expectedOutput')) {
            $expected = [string] $command.expectedOutput
            [void] (Resolve-GuardPath $root $expected)
            if (-not (Test-GuardGlob $expected 'artifacts/guards/**')) { throw "Command $($command.id) expectedOutput must be under artifacts/guards/." }
        }
        $fileArgument = [Array]::IndexOf([string[]] $command.arguments, '-File')
        if ($fileArgument -ge 0) {
            if ($fileArgument + 1 -ge $command.arguments.Count) { throw "Command $($command.id) has -File without a path." }
            $script = [string] $command.arguments[$fileArgument + 1]
            [void] (Resolve-GuardPath $root ([IO.Path]::GetRelativePath($root, (Join-Path $workingDirectory $script))) -MustExist)
        }
    }
    foreach ($detector in $binding.detectors) {
        if ($detector.commandId -notin $commandIds) { throw "Unknown command $($detector.commandId) for detector $($detector.id)." }
        if ($detector.ContainsKey('ciWorkflow')) {
            $workflow = Resolve-GuardPath $root ([string] $detector.ciWorkflow) -MustExist
            $jobParts = @([string] $detector.ciJob -split ' / ', 2)
            if ($jobParts.Count -ne 2) { throw "Detector $($detector.id) ciJob must be 'Workflow / job-id'." }
            $workflowText = [IO.File]::ReadAllText($workflow)
            if ($workflowText -notmatch "(?m)^name:\s*$([Regex]::Escape($jobParts[0]))\s*$" -or $workflowText -notmatch "(?m)^  $([Regex]::Escape($jobParts[1])):\s*$") {
                throw "Detector $($detector.id) CI workflow/job binding is missing: $($detector.ciJob)."
            }
        }
    }
    foreach ($commandId in $binding.postFullCommands) {
        if ($commandId -notin $commandIds) { throw "Unknown full Post command: $commandId" }
    }
    foreach ($area in $map.areas) {
        Assert-GuardPattern ([string] $area.pathPattern)
        if ($area.ownerSource -like 'g03:*') {
            $ownerPath = Resolve-GuardPath $root 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json' -MustExist
            $ownerInput = Get-Content -LiteralPath $ownerPath -Raw | ConvertFrom-Json -Depth 100
            if (@($ownerInput.moduleOwnership | Where-Object { $_.module -eq $area.ownerSource.Substring(4) }).Count -ne 1) {
                throw "Area $($area.id) has no unique G03 owner."
            }
        }
        elseif ($area.ownerSource -eq 'codeowners') { [void] (Resolve-GuardPath $root '.github/CODEOWNERS' -MustExist) }
        foreach ($commandId in $area.focusedCommands) {
            if ($commandId -notin $commandIds) { throw "Unknown focused command $commandId in area $($area.id)." }
        }
    }
    foreach ($risk in $map.riskTriggers) { Assert-GuardPattern ([string] $risk.pathPattern) }
    foreach ($rule in $rules) {
        $authorityPath = Resolve-GuardPath $root ([string] $rule.authority.path) -MustExist
        if ([string] $rule.authority.path -like 'docs/guards/generated/*') { throw "Rule $($rule.id) cannot use generated output as authority." }
        if ([string] $rule.authority.path -like 'docs/guards/inputs/rules/*' -and [string] $rule.authority.path -cne "docs/guards/inputs/rules/$($rule.id).json") {
            throw "Rule $($rule.id) must own its rule-file authority."
        }
        foreach ($pattern in $rule.scopePatterns) { Assert-GuardPattern ([string] $pattern) }
        foreach ($detectorId in $rule.detectors) {
            if ($detectorId -notin $detectorIds) { throw "Unknown detector $detectorId in rule $($rule.id)." }
        }
        foreach ($riskId in $rule.riskTriggerIds) {
            if ($riskId -notin $riskIds) { throw "Unknown risk trigger $riskId in rule $($rule.id)." }
        }
        if ($rule.enforcement -eq 'blocking' -and ($rule.coverage -eq 'none' -or @($rule.detectors).Count -eq 0)) {
            throw "Blocking rule $($rule.id) has no detector."
        }
        $selector = if ($rule.authority.ContainsKey('selector')) { [string] $rule.authority.selector } else { '' }
        if ($selector -match '^ruleRefs\[(.+)\]$') {
            $authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json -Depth 100
            $ref = $Matches[1]
            if (@($authority.ruleRefs | Where-Object { $_.ref -eq $ref }).Count -ne 1) {
                throw "Authority selector $selector does not identify one rule in $($rule.authority.path)."
            }
        }
        elseif ($selector -eq 'scripts') {
            $authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json -Depth 100
            if (-not $authority.PSObject.Properties['scripts']) { throw "Authority selector scripts is missing in $($rule.authority.path)." }
        }
        elseif ($selector) { throw "Unsupported authority selector $selector in rule $($rule.id)." }
    }
    return [ordered]@{
        Root = $root
        Tech = $tech
        Map = $map
        Binding = $binding
        Rules = $rules
        RuleFiles = @($ruleFiles | ForEach-Object { 'docs/guards/inputs/rules/' + $_.Name })
        BindingPath = $bindingPath
    }
}

function Get-GuardTextHash {
    param([string] $Path)
    $normalized = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function ConvertTo-GuardJson {
    param([object] $Value)
    $json = $Value | ConvertTo-Json -Depth 100
    return $json.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n"
}

function Escape-GuardMarkdown {
    param([string] $Value)
    return $Value.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function New-GuardArtifacts {
    param([string] $RepositoryRoot, [string] $Profile = 'ifx')
    $data = Get-GuardData $RepositoryRoot $Profile
    $root = $data.Root
    $sourcePaths = @(
        'docs/guards/inputs/TECH_STACK.json',
        'docs/guards/inputs/PROJECT_MAP.json',
        $data.BindingPath
    ) + $data.RuleFiles + @($data.Binding.detectors | Where-Object { $_.ContainsKey('ciWorkflow') } | ForEach-Object { [string] $_.ciWorkflow }) + @(
        if (@($data.Map.areas | Where-Object { $_.ownerSource -like 'g03:*' }).Count -gt 0) { 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json' }
        if (@($data.Map.areas | Where-Object { $_.ownerSource -eq 'codeowners' }).Count -gt 0) { '.github/CODEOWNERS' }
    ) + @(
        'docs/guards/contracts/tech-stack.schema.json',
        'docs/guards/contracts/project-map.schema.json',
        'docs/guards/contracts/rule.schema.json',
        'docs/guards/contracts/binding.schema.json',
        'docs/guards/contracts/guard-result.schema.json',
        'docs/guards/contracts/guard-manifest.schema.json',
        'docs/guards/contracts/decision.schema.json'
    ) + @($data.Rules | ForEach-Object { [string] $_.authority.path })
    $sources = @($sourcePaths | Sort-Object -Unique | ForEach-Object {
        $path = [string] $_
        [ordered]@{ path = $path; sha256NormalizedText = Get-GuardTextHash (Resolve-GuardPath $root $path -MustExist) }
    })
    $rules = @($data.Rules | Sort-Object id)
    $detectors = @($data.Binding.detectors | Sort-Object id)
    $manifest = [ordered]@{
        formatVersion = 1
        project = $data.Tech.project
        sources = $sources
        commands = @($data.Tech.commands | Sort-Object id)
        areas = @($data.Map.areas | Sort-Object id)
        riskTriggers = @($data.Map.riskTriggers | Sort-Object id)
        detectors = $detectors
        rules = $rules
        postFullCommands = @($data.Binding.postFullCommands)
    }
    $index = [Collections.Generic.List[string]]::new()
    $index.Add('# Guard rule index')
    $index.Add('')
    $index.Add('Generated from editable inputs and bound authorities. Edit `docs/guards/inputs/`, then regenerate; do not edit this file.')
    $index.Add('')
    $index.Add('| Rule | Meaning | Authority | Enforcement |')
    $index.Add('| --- | --- | --- | --- |')
    foreach ($rule in $rules) {
        $index.Add("| $($rule.id) | $(Escape-GuardMarkdown $rule.title) | ``$($rule.authority.path)`` | $($rule.enforcement) |")
    }
    $matrix = [Collections.Generic.List[string]]::new()
    $matrix.Add('# Guard coverage matrix')
    $matrix.Add('')
    $matrix.Add('Coverage describes what a detector can prove. `partial` and `none` are not equivalent to a clean result.')
    $matrix.Add('')
    $matrix.Add('| Rule | Coverage | Detector / CI job | Stages | Evidence | Known limit |')
    $matrix.Add('| --- | --- | --- | --- | --- | --- |')
    foreach ($rule in $rules) {
        $jobs = @($rule.detectors | ForEach-Object {
            $id = [string] $_
            $detector = @($detectors | Where-Object { $_.id -eq $id })[0]
            "$id ($($detector.ciJob))"
        }) -join '<br>'
        $matrix.Add("| $($rule.id) | $($rule.coverage) | $(Escape-GuardMarkdown $jobs) | $(@($rule.stages) -join ', ') | $(Escape-GuardMarkdown $rule.evidenceRequirement) | $(Escape-GuardMarkdown $rule.limitations) |")
    }
    return [ordered]@{
        'INDEX.md' = ($index -join "`n") + "`n"
        'COVERAGE_MATRIX.md' = ($matrix -join "`n") + "`n"
        'guard-manifest.json' = ConvertTo-GuardJson $manifest
    }
}

function Test-GuardGlob {
    param([string] $Path, [string] $Pattern)
    $normalized = $Path.Replace('\', '/')
    $expression = '^' + [Regex]::Escape($Pattern.Replace('\', '/')).Replace('\*\*', '.*').Replace('\*', '[^/]*').Replace('\?', '[^/]') + '$'
    return [Regex]::IsMatch($normalized, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Write-GuardText {
    param([string] $Path, [string] $Content)
    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void] [IO.Directory]::CreateDirectory($directory) }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

Export-ModuleMember -Function Get-GuardRoot, Resolve-GuardPath, Read-GuardDocument, Assert-GuardPattern, Get-GuardData, Get-GuardTextHash, ConvertTo-GuardJson, New-GuardArtifacts, Test-GuardGlob, Write-GuardText
