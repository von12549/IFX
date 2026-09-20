[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Render', 'Check', 'Import')][string] $Mode,
    [string] $ProfileDirectory,
    [string] $ProfileLayoutPath,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $DocsDirectory,
    [switch] $Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
function Resolve-UnderRoot([string] $value) {
    $full = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $root $value }))
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay under TargetRoot: $value" }
    return $full
}
$layoutMode = -not [string]::IsNullOrWhiteSpace($ProfileLayoutPath)
if ($layoutMode -eq (-not [string]::IsNullOrWhiteSpace($ProfileDirectory))) { throw 'Supply exactly one of ProfileDirectory or ProfileLayoutPath.' }
function Resolve-RepositoryPath([string] $value) {
    $normalized = $value.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or
        $normalized -match '[*?]' -or @($normalized -split '/' | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        throw "Unsafe repository-relative profile layout path: $value"
    }
    return Resolve-UnderRoot $normalized
}
if ($layoutMode) {
    $layoutPath = Resolve-UnderRoot $ProfileLayoutPath
    if (-not [IO.File]::Exists($layoutPath)) { throw "ProfileLayoutPath does not exist: $layoutPath" }
    $layout = Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json -AsHashtable -Depth 20
    $expectedLayoutKeys = @('formatVersion', 'profile', 'projectMap', 'rulesDirectory', 'techStack', 'viewsDirectory')
    if ($layout.formatVersion -ne 1 -or (@($layout.Keys | Sort-Object) -join "`n") -cne (@($expectedLayoutKeys | Sort-Object) -join "`n")) { throw 'Invalid profile layout JSON.' }
    $profilePath = Resolve-RepositoryPath ([string]$layout.profile)
    $projectMapPath = Resolve-RepositoryPath ([string]$layout.projectMap)
    $techStackPath = Resolve-RepositoryPath ([string]$layout.techStack)
    $ruleRoot = Resolve-RepositoryPath ([string]$layout.rulesDirectory)
    $layoutViewsRoot = Resolve-RepositoryPath ([string]$layout.viewsDirectory)
    $profileRoot = [IO.Path]::GetDirectoryName($profilePath)
    $docsRoot = if ($DocsDirectory) { Resolve-UnderRoot $DocsDirectory } else { $layoutViewsRoot }
}
else {
    $profileRoot = Resolve-UnderRoot $ProfileDirectory
    if (-not [IO.Directory]::Exists($profileRoot)) { throw "ProfileDirectory does not exist: $profileRoot" }
    $profilePath = Join-Path $profileRoot 'profile.json'
    $projectMapPath = Join-Path $profileRoot 'project-map.json'
    $techStackPath = Join-Path $profileRoot 'tech-stack.json'
    $ruleRoot = Join-Path $profileRoot 'rules'
    $docsRoot = if ($DocsDirectory) { Resolve-UnderRoot $DocsDirectory } else { Join-Path $profileRoot 'views' }
}
if ($docsRoot -eq $profileRoot) { throw 'DocsDirectory must differ from ProfileDirectory.' }
$utf8 = [Text.UTF8Encoding]::new($false)

function Normalize-Text([string] $value) { return $value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n" }
function Hash-Bytes([byte[]] $bytes) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant() }
function Read-JsonFile([string] $path, [string] $schemaName) {
    if (-not [IO.File]::Exists($path)) { throw "Missing profile input: $path" }
    $schema = Join-Path $packageRoot "contracts/$schemaName.schema.json"
    if (-not (Test-Json -Path $path -SchemaFile $schema -ErrorAction Stop)) { throw "Invalid $schemaName JSON: $path" }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
}
function Cell([object] $value) {
    if ($value -is [array]) { $value = $value -join ', ' }
    return ([string] $value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}
function Add-Source([string] $title, [string] $sourceName, [string] $schema, [string] $table) {
    $sourcePath = Join-Path $profileRoot $sourceName
    $raw = Normalize-Text ([IO.File]::ReadAllText($sourcePath))
    $hash = Hash-Bytes ([IO.File]::ReadAllBytes($sourcePath))
    $header = "# $title`n`nGenerated view of ``$sourceName``. Edit the JSON block for policy changes, then run Import. Keep explanations in ``notes/``.`n`n"
    $header += "<!-- guard-config-source: $sourceName sha256: $hash -->`n`n"
    $body = "$table`n`n``````json`n$raw```````n"
    return Normalize-Text ($header + $body)
}
function Relative([string] $path) { return [IO.Path]::GetRelativePath($root, $path).Replace('\', '/') }
function Hash-Text([string] $value) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))).ToLowerInvariant() }
function Add-LayoutHeader([string] $title, [string[]] $sourceNames) {
    $sources = @($sourceNames | ForEach-Object {
        $full = switch ($_) {
            'profile.json' { $profilePath }
            'project-map.json' { $projectMapPath }
            'tech-stack.json' { $techStackPath }
            default {
                if (-not $_.StartsWith('rules/')) { throw "Unknown profile authority source: $_" }
                Join-Path $ruleRoot ([IO.Path]::GetFileName($_))
            }
        }
        [pscustomobject]@{ path = Relative $full; role = 'authority'; fullPath = $full }
    } | Sort-Object path, role)
    $material = @($sources | ForEach-Object { "$($_.path)`n$($_.role)`n$(Normalize-Text ([IO.File]::ReadAllText($_.fullPath)))" }) -join "`n"
    $lines = @($sources | ForEach-Object { "- ``$($_.path)`` — $($_.role)" })
    return Normalize-Text ("# $title`n`n<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->`n`nComposite SHA-256: ``$(Hash-Text $material)```n`nSources:`n`n$($lines -join "`n")")
}

$profile = Read-JsonFile $profilePath 'profile'
$map = Read-JsonFile $projectMapPath 'project-map'
$tech = Read-JsonFile $techStackPath 'tech-stack'
if (-not [IO.Directory]::Exists($ruleRoot)) { throw "Missing rules directory: $ruleRoot" }
$ruleFiles = @(Get-ChildItem -LiteralPath $ruleRoot -File -Filter '*.json' | Sort-Object Name)
if ($ruleFiles.Count -eq 0) { throw 'At least one rule is required.' }
$rules = @($ruleFiles | ForEach-Object { Read-JsonFile $_.FullName 'rule' })
$expected = [ordered]@{}
$expected['PROFILE.md'] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader 'Profile' @('profile.json'))`n| Field | Value |`n| --- | --- |`n| Project ID | $(Cell $profile.projectId) |") } else { Add-Source 'Profile' 'profile.json' 'profile' "| Field | Value |`n| --- | --- |`n| Project ID | $(Cell $profile.projectId) |" }
$areaLines = @($map.areas | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.pathPattern) | $(Cell $_.layer) | $(Cell $_.owner) | $(Cell $_.similarImplementationRoot) | $(Cell $_.focusedCommands) |" })
$riskLines = @($map.riskTriggers | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.pathPattern) | $(Cell $_.reason) |" })
$mapTable = "## Areas`n`n| ID | Path | Layer | Owner | Similar implementation | Focused commands |`n| --- | --- | --- | --- | --- | --- |`n$($areaLines -join "`n")`n`n## Risk triggers`n`n| ID | Path | Reason |`n| --- | --- | --- |`n$($riskLines -join "`n")"
$expected['PROJECT_MAP.md'] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader 'Project map' @('project-map.json'))`n$mapTable") } else { Add-Source 'Project map' 'project-map.json' 'project-map' $mapTable }
$commandLines = @($tech.commands | ForEach-Object { "| $(Cell $_.id) | $(Cell $_.executable) | $(Cell $_.arguments) | $(Cell $_.workingDirectory) |" })
$techTable = "| Languages | .NET gate target | Framework |`n| --- | --- | --- |`n| $(Cell $tech.targetLanguages) | $(Cell $tech.testProject.targetFramework) | $(Cell $tech.testProject.framework) |`n`n## Commands`n`n| ID | Executable | Arguments | Working directory |`n| --- | --- | --- | --- |`n$($commandLines -join "`n")"
$expected['TECH_STACK.md'] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader 'Tech stack' @('tech-stack.json'))`n$techTable") } else { Add-Source 'Tech stack' 'tech-stack.json' 'tech-stack' $techTable }
foreach ($i in 0..($ruleFiles.Count - 1)) {
    $file = $ruleFiles[$i]
    $rule = $rules[$i]
    $table = "| Field | Value |`n| --- | --- |`n| ID | $(Cell $rule.id) |`n| Kind | $(Cell $rule.kind) |`n| Enforcement | $(Cell $rule.enforcement) |`n| Detector coverage | $(Cell $rule.coverage) |`n| Authority | $(Cell $rule.authority) |`n| Applies to | $(Cell $rule.appliesTo) |"
    if (-not $layoutMode) {
        if ($rule.kind -eq 'forbidden-project-reference') { $table += "`n| Source pattern | $(Cell $rule.sourcePattern) |`n| Forbidden target | $(Cell $rule.forbiddenTargetPattern) |`n| Negative source | $(Cell $rule.negativeFixture.sourceProject) |`n| Negative reference | $(Cell $rule.negativeFixture.referenceInclude) |" }
        if ($rule.kind -eq 'forbidden-type-dependency') { $table += "`n| Source assembly/namespace | $(Cell $rule.sourceAssembly):$(Cell $rule.sourceNamespace) |`n| Forbidden assembly/namespace | $(Cell $rule.forbiddenAssembly):$(Cell $rule.forbiddenNamespace) |`n| Minimum matches | $(Cell $rule.minimumMatches) |" }
        if ($rule.kind -eq 'interface-implementation-location') { $table += "`n| Interface | $(Cell $rule.interfaceAssembly):$(Cell $rule.interfaceType) |`n| Implementation location | $(Cell $rule.implementationAssembly):$(Cell $rule.implementationNamespace) |`n| Minimum implementations | $(Cell $rule.minimumMatches) |" }
    }
    $expected["rules/$($file.BaseName).md"] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader "$($rule.id): $($rule.title)" @("rules/$($file.Name)"))`n$table") } else { Add-Source "$($rule.id): $($rule.title)" "rules/$($file.Name)" 'rule' $table }
}
$coverageLines = @($rules | ForEach-Object { "| [$($_.id)](rules/$($_.id).md) | $(Cell $_.enforcement) | $(Cell $_.kind) | $(Cell $_.coverage) | $(Cell $_.authority) |" })
$expected['COVERAGE.md'] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader 'V3 stage coverage' @($ruleFiles | ForEach-Object { "rules/$($_.Name)" }))`nThis table describes only detectors configured in the V3 stage profile. External gates require separate evidence; advisory rules do not block.`n`n| Rule | Enforcement | Detector | Coverage | Authority |`n| --- | --- | --- | --- | --- |`n$($coverageLines -join "`n")") } else { Normalize-Text ("# V3 stage coverage`n`nThis table describes only detectors configured in the V3 stage profile. External gates require separate evidence; advisory rules do not block.`n`n| Rule | Enforcement | Detector | Coverage | Authority |`n| --- | --- | --- | --- | --- |`n$($coverageLines -join "`n")") }
$expected['README.md'] = if ($layoutMode) { Normalize-Text ("$(Add-LayoutHeader "$($profile.projectId) guard configuration views" @('profile.json','project-map.json','tech-stack.json'))`nJSON in the parent profile is authoritative. These Markdown files are generated, read-only views; edit authority JSON and rerun Render.`n`n- [Profile](PROFILE.md)`n- [Project map](PROJECT_MAP.md)`n- [Tech stack](TECH_STACK.md)`n- [Stage coverage](COVERAGE.md)`n- Rules: $(@($rules | ForEach-Object { "[$($_.id)](rules/$($_.id).md)" }) -join ', ')") } else { Normalize-Text ("# $($profile.projectId) guard configuration views`n`nJSON files in the parent profile are the machine authority. These views are generated from them. Edit a fenced JSON block and run Import to propose or apply a semantic change; edit ``notes/`` for human rationale. Render refreshes views; Check fails on drift.`n`n- [Profile](PROFILE.md)`n- [Project map](PROJECT_MAP.md)`n- [Tech stack](TECH_STACK.md)`n- [Stage coverage](COVERAGE.md)`n- Rules: $(@($rules | ForEach-Object { "[$($_.id)](rules/$($_.id).md)" }) -join ', ')`n") }

function Write-Views {
    if ([IO.Directory]::Exists($docsRoot)) {
        $docsPrefix = [IO.Path]::GetFullPath($docsRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        foreach ($stale in @(Get-ChildItem -LiteralPath $docsRoot -File -Recurse)) {
            $name = [IO.Path]::GetRelativePath($docsRoot, $stale.FullName).Replace('\', '/')
            if ($name -in @($expected.Keys)) { continue }
            $resolved = [IO.Path]::GetFullPath($stale.FullName)
            if (-not $resolved.StartsWith($docsPrefix, [StringComparison]::OrdinalIgnoreCase) -or ($stale.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unsafe stale view: $name" }
            Remove-Item -LiteralPath $resolved -Force
        }
    }
    foreach ($name in $expected.Keys) {
        $path = Join-Path $docsRoot $name
        [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
        [IO.File]::WriteAllText($path, $expected[$name], $utf8)
    }
    Write-Host "Rendered $($expected.Count) Markdown views: $docsRoot"
}
function Check-Views {
    if (-not [IO.Directory]::Exists($docsRoot)) { throw "Missing generated views: $docsRoot" }
    foreach ($name in $expected.Keys) {
        $path = Join-Path $docsRoot $name
        if (-not [IO.File]::Exists($path)) { throw "Missing Markdown view: $name" }
        if ([IO.File]::ReadAllText($path) -cne $expected[$name]) { throw "Markdown view drift: $name" }
    }
    $extra = @(Get-ChildItem -LiteralPath $docsRoot -File -Recurse | ForEach-Object { [IO.Path]::GetRelativePath($docsRoot, $_.FullName).Replace('\', '/') } | Where-Object { $_ -notin @($expected.Keys) })
    if ($extra.Count -gt 0) { throw "Unexpected generated views: $($extra -join ', ')" }
    Write-Host "Markdown views match JSON: $docsRoot"
}

if ($Mode -eq 'Render') { Write-Views; exit 0 }
if ($Mode -eq 'Check') { Check-Views; exit 0 }
if ($layoutMode) { throw 'Import is not supported for a split profile layout.' }
if (-not [IO.Directory]::Exists($docsRoot)) { throw "Missing generated views: $docsRoot" }
$changes = [ordered]@{}
foreach ($name in @('PROFILE.md', 'PROJECT_MAP.md', 'TECH_STACK.md') + @($ruleFiles | ForEach-Object { "rules/$($_.BaseName).md" })) {
    $path = Join-Path $docsRoot $name
    if (-not [IO.File]::Exists($path)) { throw "Missing Markdown view: $name" }
    $text = Normalize-Text ([IO.File]::ReadAllText($path))
    $match = [Regex]::Match($text, '(?s)<!-- guard-config-source: (?<source>[^\s]+) sha256: (?<hash>[0-9a-f]{64}) -->.*?```json\n(?<json>.*?)\n```')
    if (-not $match.Success) { throw "Malformed editable JSON block: $name" }
    $sourceName = $match.Groups['source'].Value
    $expectedSource = switch ($name) { 'PROFILE.md' { 'profile.json' } 'PROJECT_MAP.md' { 'project-map.json' } 'TECH_STACK.md' { 'tech-stack.json' } default { "rules/$([IO.Path]::GetFileNameWithoutExtension($name)).json" } }
    if ($sourceName -cne $expectedSource) { throw "Markdown source mismatch: $name" }
    $sourcePath = Join-Path $profileRoot $sourceName
    $proposal = Normalize-Text $match.Groups['json'].Value
    $current = Normalize-Text ([IO.File]::ReadAllText($sourcePath))
    if ($proposal -ceq $current) { continue }
    $currentHash = Hash-Bytes ([IO.File]::ReadAllBytes($sourcePath))
    if ($currentHash -cne $match.Groups['hash'].Value) { throw "JSON changed since Markdown render: $sourceName" }
    $schemaName = if ($sourceName.StartsWith('rules/')) { 'rule' } else { [IO.Path]::GetFileNameWithoutExtension($sourceName) }
    $schema = Join-Path $packageRoot "contracts/$schemaName.schema.json"
    if (-not (Test-Json -Json $proposal -SchemaFile $schema -ErrorAction Stop)) { throw "Imported JSON violates $schemaName schema: $name" }
    $changes[$sourcePath] = $proposal
}
if ($changes.Count -eq 0) { Write-Host 'No semantic changes in Markdown JSON blocks.'; exit 0 }
if (-not $Apply) {
    Write-Host "Import preview: $($changes.Count) JSON file(s). Review the proposed content, then re-run with -Apply."
    foreach ($path in $changes.Keys) { Write-Host "Proposed $([IO.Path]::GetRelativePath($profileRoot, $path)):"; Write-Output $changes[$path] }
    exit 0
}
$before = @{}
try {
    foreach ($path in $changes.Keys) { $before[$path] = [IO.File]::ReadAllBytes($path); [IO.File]::WriteAllText($path, $changes[$path], $utf8) }
    & (Join-Path $packageRoot 'scripts/Invoke-V3.ps1') -Mode Validate -ProfileDirectory $profileRoot -TargetRoot $root -OutputDirectory $docsRoot | Out-Null
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Profile validation failed after import.' }
}
catch {
    foreach ($path in $before.Keys) { [IO.File]::WriteAllBytes($path, $before[$path]) }
    throw
}
Write-Host "Imported $($changes.Count) JSON file(s)."
# Re-evaluate expected views after applying changes in a fresh invocation.
& $PSCommandPath -Mode Render -ProfileDirectory $profileRoot -TargetRoot $root -DocsDirectory $docsRoot
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Render failed after import.' }
