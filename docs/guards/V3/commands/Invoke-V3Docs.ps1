[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Render', 'Check')][string] $Mode,
    [Parameter(Mandatory)][string] $ProfileDirectory,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $DocsDirectory,
    [string] $PackageDirectory,
    [string] $DocsMapPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$engineRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)

function Resolve-UnderRoot([string] $value) {
    $full = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $root $value }))
    if ($full -ne $root -and -not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay under TargetRoot: $value" }
    return $full
}
function Relative([string] $path) { return [IO.Path]::GetRelativePath($root, $path).Replace('\', '/') }
function Normalize([string] $value) { return $value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n" }
function Hash([string] $value) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))).ToLowerInvariant() }
function Cell([object] $value) {
    if ($null -eq $value) { return '' }
    if ($value -is [array]) { $value = $value -join ', ' }
    return ([string] $value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}
function Read-Json([string] $path, [string] $schema) {
    if (-not [IO.File]::Exists($path)) { throw "Missing JSON input: $path" }
    if ($schema -and -not (Test-Json -Path $path -SchemaFile $schema -ErrorAction Stop)) { throw "Invalid JSON input: $path" }
    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable -Depth 100
}
function New-Header([string] $title, [object[]] $sources) {
    $ordered = @($sources | Sort-Object path, role)
    $material = @($ordered | ForEach-Object { "$($_.path)`n$($_.role)`n$(Normalize ([IO.File]::ReadAllText($_.fullPath)))" }) -join "`n"
    $lines = @($ordered | ForEach-Object { "- ``$($_.path)`` — $($_.role)" })
    return Normalize ("# $title`n`n<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->`n`nComposite SHA-256: ``$(Hash $material)```n`nSources:`n`n$($lines -join "`n")")
}
function Add-Expected([Collections.IDictionary] $set, [string] $rootDirectory, [string] $relative, [string] $content) {
    $path = [IO.Path]::GetFullPath((Join-Path $rootDirectory $relative))
    $prefix = [IO.Path]::GetFullPath($rootDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Generated document escapes its root: $relative" }
    $set[$path] = Normalize $content
}

$profileRoot = Resolve-UnderRoot $ProfileDirectory
if (-not [IO.Directory]::Exists($profileRoot)) { throw "ProfileDirectory does not exist: $profileRoot" }
$viewsRoot = if ($DocsDirectory) { Resolve-UnderRoot $DocsDirectory } else { Join-Path $profileRoot 'views' }
if ($viewsRoot -eq $profileRoot) { throw 'DocsDirectory must differ from ProfileDirectory.' }
$overlayRoot = if ($PackageDirectory) { Resolve-UnderRoot $PackageDirectory } else { [IO.Path]::GetFullPath((Join-Path $profileRoot '../..')) }
$mapPath = if ($DocsMapPath) { Resolve-UnderRoot $DocsMapPath } else { Join-Path $overlayRoot 'docs/docs-map.json' }

$profileSchemaRoot = Join-Path $engineRoot 'contracts'
$profile = Read-Json (Join-Path $profileRoot 'profile.json') (Join-Path $profileSchemaRoot 'profile.schema.json')
$map = Read-Json (Join-Path $profileRoot 'project-map.json') (Join-Path $profileSchemaRoot 'project-map.schema.json')
$tech = Read-Json (Join-Path $profileRoot 'tech-stack.json') (Join-Path $profileSchemaRoot 'tech-stack.schema.json')
$ruleFiles = @(Get-ChildItem -LiteralPath (Join-Path $profileRoot 'rules') -File -Filter '*.json' | Sort-Object Name)
if ($ruleFiles.Count -eq 0) { throw 'At least one rule is required.' }
$rules = @($ruleFiles | ForEach-Object { Read-Json $_.FullName (Join-Path $profileSchemaRoot 'rule.schema.json') })
$expected = [ordered]@{}

function Profile-Header([string] $title, [string[]] $paths) {
    $sources = @($paths | ForEach-Object { $full = Join-Path $profileRoot $_; [pscustomobject]@{ path = Relative $full; role = 'authority'; fullPath = $full } })
    return New-Header $title $sources
}
$areaLines = @($map.areas | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.pathPattern) | $(Cell $_.layer) | $(Cell $_.owner) | $(Cell $_.similarImplementationRoot) | $(Cell $_.focusedCommands) |" })
$riskLines = @($map.riskTriggers | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.pathPattern) | $(Cell $_.reason) |" })
$commandLines = @($tech.commands | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.executable) | $(Cell $_.arguments) | $(Cell $_.workingDirectory) |" })
$coverageLines = @($rules | ForEach-Object { "| [$($_.id)](rules/$($_.id).md) | $(Cell $_.enforcement) | $(Cell $_.kind) | $(Cell $_.coverage) | $(Cell $_.authority) |" })
Add-Expected $expected $viewsRoot 'PROFILE.md' "$(Profile-Header 'Profile' @('profile.json'))`n| Field | Value |`n| --- | --- |`n| Project ID | $(Cell $profile.projectId) |"
Add-Expected $expected $viewsRoot 'PROJECT_MAP.md' "$(Profile-Header 'Project map' @('project-map.json'))`n## Areas`n`n| ID | Path | Layer | Owner | Similar implementation | Focused commands |`n| --- | --- | --- | --- | --- | --- |`n$($areaLines -join "`n")`n`n## Risk triggers`n`n| ID | Path | Reason |`n| --- | --- | --- |`n$($riskLines -join "`n")"
Add-Expected $expected $viewsRoot 'TECH_STACK.md' "$(Profile-Header 'Tech stack' @('tech-stack.json'))`n| Languages | .NET gate target | Framework |`n| --- | --- | --- |`n| $(Cell $tech.targetLanguages) | $(Cell $tech.testProject.targetFramework) | $(Cell $tech.testProject.framework) |`n`n## Commands`n`n| ID | Executable | Arguments | Working directory |`n| --- | --- | --- | --- |`n$($commandLines -join "`n")"
foreach ($i in 0..($ruleFiles.Count - 1)) {
    $file = $ruleFiles[$i]; $rule = $rules[$i]
    $table = "| Field | Value |`n| --- | --- |`n| ID | $(Cell $rule.id) |`n| Kind | $(Cell $rule.kind) |`n| Enforcement | $(Cell $rule.enforcement) |`n| Detector coverage | $(Cell $rule.coverage) |`n| Authority | $(Cell $rule.authority) |`n| Applies to | $(Cell $rule.appliesTo) |"
    Add-Expected $expected $viewsRoot "rules/$($file.BaseName).md" "$(Profile-Header "$($rule.id): $($rule.title)" @("rules/$($file.Name)"))`n$table"
}
Add-Expected $expected $viewsRoot 'COVERAGE.md' "$(Profile-Header 'V3 stage coverage' @($ruleFiles | ForEach-Object { "rules/$($_.Name)" }))`nThis table describes only detectors configured in the V3 stage profile. External gates require separate evidence; advisory rules do not block.`n`n| Rule | Enforcement | Detector | Coverage | Authority |`n| --- | --- | --- | --- | --- |`n$($coverageLines -join "`n")"
Add-Expected $expected $viewsRoot 'README.md' "$(Profile-Header "$($profile.projectId) guard configuration views" @('profile.json','project-map.json','tech-stack.json') + @($ruleFiles | ForEach-Object { "rules/$($_.Name)" }))`nJSON in the parent profile is authoritative. These Markdown files are generated, read-only views; edit authority JSON and rerun Render.`n`n- [Profile](PROFILE.md)`n- [Project map](PROJECT_MAP.md)`n- [Tech stack](TECH_STACK.md)`n- [Stage coverage](COVERAGE.md)`n- Rules: $(@($rules | ForEach-Object { "[$($_.id)](rules/$($_.id).md)" }) -join ', ')"

if ([IO.File]::Exists($mapPath)) {
    $docsSchema = Join-Path $overlayRoot 'contracts/docs-map.schema.json'
    $docsMap = Read-Json $mapPath $docsSchema
    $allFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](\.git|artifacts|bin|obj)[\\/]' })
    foreach ($document in $docsMap.documents) {
        $sources = @()
        foreach ($source in $document.sources) {
            $pattern = [string] $source.path
            if ($pattern.StartsWith('/') -or $pattern -match '^[A-Za-z]:' -or $pattern -match '(^|/)\.\.(/|$)') { throw "Unsafe docs source: $pattern" }
            $matches = if ($pattern.IndexOfAny([char[]]'*?[') -ge 0) {
                $wildcard = [WildcardPattern]::new($pattern, [Management.Automation.WildcardOptions]::IgnoreCase)
                @($allFiles | Where-Object { $wildcard.IsMatch((Relative $_.FullName)) })
            } else {
                $full = Resolve-UnderRoot $pattern
                if ([IO.File]::Exists($full)) { @([IO.FileInfo]::new($full)) } else { @() }
            }
            $matches = @($matches)
            if ($matches.Count -eq 0) { throw "Docs source matched no files: $pattern" }
            $sources += @($matches | ForEach-Object { [pscustomobject]@{ path = Relative $_.FullName; role = [string]$source.role; fullPath = $_.FullName } })
        }
        $sources = @($sources | Sort-Object path, role -Unique)
        $header = New-Header ([string]$document.title) $sources
        $commandsPath = Join-Path $overlayRoot 'shared/commands.json'
        $commands = Read-Json $commandsPath $null
        switch ([string]$document.renderer) {
            'overview' {
                $system = Read-Json (Join-Path $overlayRoot 'guard-system.json') $null
                $stages = @(Get-ChildItem -LiteralPath (Join-Path $overlayRoot 'stages') -Recurse -Filter 'stage.json' | Sort-Object FullName | ForEach-Object { Read-Json $_.FullName $null })
                $rows = @($stages | ForEach-Object { "| $($_.id) | $($_.enforcement) | $($_.executionClass) | $(@($_.dependencies) -join ', ') | $(@($_.commands) -join ', ') |" })
                $body = "$header`nPackage ``$($system.packageId)`` is an ``$($system.role)`` package using engine ``$($system.engine.package)``. Authority/configuration, generated candidates, activated copies and runtime evidence are distinct lifecycle layers.`n`n| Stage | Enforcement | Execution class | Dependencies | Commands |`n| --- | --- | --- | --- | --- |`n$($rows -join "`n")"
            }
            'commands' {
                $rows = @($commands.commands | ForEach-Object { "| $($_.id) | $($_.kind) | ``$($_.entryPoint)`` | $(@($_.stages) -join ', ') | $($_.mutability) | $($_.requiresExplicitAcceptance) |" })
                $details = @($commands.commands | ForEach-Object { "## $($_.id)`n`n- Audiences: $(@($_.audiences) -join ', ')`n- Inputs: $(@($_.inputs) -join '; ')`n- Outputs: $(@($_.outputs) -join '; ')`n- Evidence: $(if (@($_.evidence).Count) { @($_.evidence) -join '; ' } else { '(none)' })" }) -join "`n`n"
                $body = "$header`n| Command | Kind | Entry point | Stages | Mutability | Explicit acceptance |`n| --- | --- | --- | --- | --- | --- |`n$($rows -join "`n")`n`n$details"
            }
            'post' {
                $post = Read-Json (Join-Path $overlayRoot 'stages/post/stage.json') $null
                $postCommands = @($commands.commands | Where-Object { 'post' -in @($_.stages) })
                $gateRows = @($post.gates | ForEach-Object { "| $($_.id) | $($_.trustContract.type) | $($_.trustContract.executesHead) | $($_.trustContract.consumesHeadArtifacts) | $(Cell $_.trustContract.guarantee) |" })
                $ruleRows = @($rules | ForEach-Object { "| $($_.id) | $($_.enforcement) | $($_.kind) | $($_.coverage) |" })
                $body = "$header`nPost commands: $(@($postCommands | ForEach-Object id) -join ', ').`n`n## Gates`n`n| Gate | Trust type | Executes head | Consumes head artifacts | Guarantee |`n| --- | --- | --- | --- | --- |`n$($gateRows -join "`n")`n`n## Stage profile rules`n`n| Rule | Enforcement | Detector | Coverage |`n| --- | --- | --- | --- |`n$($ruleRows -join "`n")"
            }
            'ci' {
                $ci = Read-Json (Join-Path $overlayRoot 'stages/ci/stage.json') $null
                $jobs = Read-Json (Join-Path $overlayRoot 'ci/jobs.json') $null
                $rows = @($jobs.jobs | ForEach-Object { $gate = if ($_.ContainsKey('gate')) { $_.gate } else { '' }; "| $($_.id) | $($_.mode) | $gate | $($_.trigger) | $($_.blocking) |" })
                $body = "$header`nWorkflow: ``$($jobs.automaticGuardWorkflow)``. Merge enforcement: $($jobs.mergeEnforcement). Ruleset strict: $($jobs.ruleset.strict). Trusted-base execution: $($jobs.trustedBase.execution).`n`n| Required check | Mode | Gate | Trigger | Blocking |`n| --- | --- | --- | --- | --- |`n$($rows -join "`n")`n`nCI Stage dependencies: $(@($ci.dependencies) -join ', ')."
            }
            default { throw "Unknown docs renderer: $($document.renderer)" }
        }
        Add-Expected $expected $overlayRoot ([string]$document.output) $body
    }
}

$managedRoots = @($viewsRoot)
if ([IO.File]::Exists($mapPath)) { $managedRoots += Join-Path $overlayRoot 'docs/generated' }
if ($Mode -eq 'Render') {
    foreach ($managedRoot in $managedRoots) {
        if (-not [IO.Directory]::Exists($managedRoot)) { continue }
        $prefix = [IO.Path]::GetFullPath($managedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        foreach ($file in @(Get-ChildItem -LiteralPath $managedRoot -Recurse -File)) {
            if ($expected.Contains($file.FullName)) { continue }
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or -not $file.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe stale generated document: $($file.FullName)" }
            Remove-Item -LiteralPath $file.FullName -Force
        }
    }
    foreach ($path in $expected.Keys) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)); [IO.File]::WriteAllText($path, $expected[$path], $utf8) }
    Write-Host "Rendered $($expected.Count) read-only Markdown documents."
    exit 0
}

foreach ($path in $expected.Keys) {
    if (-not [IO.File]::Exists($path)) { throw "Missing generated Markdown: $(Relative $path)" }
    if ([IO.File]::ReadAllText($path) -cne $expected[$path]) { throw "Generated Markdown drift: $(Relative $path)" }
}
foreach ($managedRoot in $managedRoots) {
    if (-not [IO.Directory]::Exists($managedRoot)) { throw "Missing generated docs directory: $(Relative $managedRoot)" }
    $extras = @(Get-ChildItem -LiteralPath $managedRoot -Recurse -File | Where-Object { -not $expected.Contains($_.FullName) })
    if ($extras.Count -gt 0) { throw "Unexpected generated Markdown: $(@($extras | ForEach-Object { Relative $_.FullName }) -join ', ')" }
}
Write-Host "Generated Markdown matches $($expected.Count) authority-derived documents."
