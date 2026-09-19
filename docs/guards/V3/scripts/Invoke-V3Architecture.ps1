[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Draft', 'Review', 'Adopt')][string] $Mode,
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][string] $AnalysisDirectory,
    [string] $EvidenceDirectory,
    [string] $ProfileDirectory,
    [string] $ProfileLayoutPath,
    [string] $DestinationProfileDirectory,
    [string] $ProjectId,
    [string] $TargetFramework = 'net10.0',
    [switch] $AcceptDocument
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
Import-Module (Join-Path $packageRoot 'scripts/ProfileLayout.psm1') -Force
$activeLayout = if ($ProfileDirectory -or $ProfileLayoutPath) {
    Resolve-V3ProfileLayout -TargetRoot $root -ProfileDirectory $ProfileDirectory -ProfileLayoutPath $ProfileLayoutPath -SchemaPath (Join-Path $packageRoot 'contracts/profile-layout.schema.json')
} else { $null }
$prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
function Resolve-UnderRoot([string] $value) {
    $path = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $root $value }))
    if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay under TargetRoot: $value" }
    return $path
}
function Lf([string] $value) { return $value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n" }
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Lf([string] $path, [string] $value) {
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, (Lf $value), $utf8)
}
function Json([object] $value) { return Lf (ConvertTo-Json -InputObject $value -Depth 100) }
function Canonical-Json([string] $value) { return ConvertTo-Json -InputObject ($value | ConvertFrom-Json -AsHashtable -Depth 100) -Compress -Depth 100 }
function Hash([string] $value) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($value))).ToLowerInvariant() }
function Read-Contract([string] $path, [string] $schemaName) {
    $schema = Join-Path $packageRoot "contracts/$schemaName.schema.json"
    if (-not [IO.File]::Exists($path) -or -not (Test-Json -Path $path -SchemaFile $schema -ErrorAction Stop)) { throw "Invalid or missing $schemaName input: $path" }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
}
function Block([string] $source, [object] $value) { return "<!-- guard-config: $source -->`n``````json`n$(Json $value)```````n" }
function Match-Glob([string] $path, [string] $pattern) {
    $p = $pattern.Replace('\', '/')
    $regex = [Text.StringBuilder]::new('^')
    for ($i = 0; $i -lt $p.Length; $i++) {
        if ($i + 2 -lt $p.Length -and $p.Substring($i, 3) -eq '**/') { [void] $regex.Append('(?:.*/)?'); $i += 2 }
        elseif ($i + 1 -lt $p.Length -and $p.Substring($i, 2) -eq '**') { [void] $regex.Append('.*'); $i++ }
        elseif ($p[$i] -eq '*') { [void] $regex.Append('[^/]*') }
        elseif ($p[$i] -eq '?') { [void] $regex.Append('[^/]') }
        else { [void] $regex.Append([Regex]::Escape([string] $p[$i])) }
    }
    [void] $regex.Append('$')
    return [Regex]::IsMatch($path.Replace('\', '/'), $regex.ToString(), [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

$analysis = Resolve-UnderRoot $AnalysisDirectory
$evidence = if ($EvidenceDirectory) { Resolve-UnderRoot $EvidenceDirectory } else { $analysis }
$inventoryPath = Join-Path $analysis 'inventory.json'
if (-not [IO.File]::Exists($inventoryPath)) { throw "Run Analyze first: $inventoryPath" }
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ($inventory.formatVersion -ne 1) { throw 'Unsupported inventory format.' }
$architecturePath = Join-Path $evidence 'ARCHITECTURE.md'
$technicalPath = Join-Path $evidence 'TECHNICAL.md'

if ($Mode -eq 'Draft') {
    if ($EvidenceDirectory -and (-not [IO.File]::Exists($architecturePath) -or -not [IO.File]::Exists($technicalPath))) {
        throw 'EvidenceDirectory must contain reviewed ARCHITECTURE.md and TECHNICAL.md; update them through the maintenance Preview/Apply command.'
    }
    if ($activeLayout) {
        $profile = Read-Contract $activeLayout.Profile 'profile'
        $map = Read-Contract $activeLayout.ProjectMap 'project-map'
        $tech = Read-Contract $activeLayout.TechStack 'tech-stack'
        $rules = @{}
        foreach ($file in @(Get-ChildItem -LiteralPath $activeLayout.RulesDirectory -File -Filter '*.json' | Sort-Object Name)) { $rules[$file.Name] = Read-Contract $file.FullName 'rule' }
    }
    else {
        $id = if ($ProjectId) { $ProjectId } else { [IO.Path]::GetFileName($root).ToLowerInvariant() -replace '[^a-z0-9-]', '-' }
        if ($id -cnotmatch '^[a-z][a-z0-9-]+$') { throw 'Supply a valid ProjectId for the architecture draft.' }
        if ($TargetFramework -cnotmatch '^net[0-9]+\.0$') { throw 'TargetFramework must be netN.0.' }
        $profile = [ordered]@{ formatVersion = 1; projectId = $id }
        $candidates = @($inventory.areaCandidates | Select-Object -First 20)
        if ($candidates.Count -eq 0) { $candidates = @('unreviewed') }
        $areas = @($candidates | ForEach-Object {
            $candidate = [string] $_
            $areaId = ($candidate -replace '[^A-Za-z0-9]', '-').Trim('-')
            [ordered]@{ id = $areaId; pathPattern = "$candidate/**"; layer = 'UNREVIEWED'; owner = 'UNREVIEWED'; similarImplementationRoot = $candidate; focusedCommands = @('review-test') }
        })
        $map = [ordered]@{ formatVersion = 1; areas = $areas; riskTriggers = @() }
        $tech = [ordered]@{ formatVersion = 1; targetLanguages = @('C#'); commands = @([ordered]@{ id = 'review-test'; executable = 'dotnet'; arguments = @('test'); workingDirectory = '.' }); testProject = [ordered]@{ targetFramework = $TargetFramework; framework = 'xunit' } }
        $rules = @{ 'ARCH.UNCONFIGURED.json' = [ordered]@{ formatVersion = 1; id = 'ARCH.UNCONFIGURED'; title = 'Replace with reviewed target rules'; kind = 'none'; enforcement = 'advisory'; coverage = 'none'; authority = 'Analysis draft only'; appliesTo = @('unreviewed/**') } }
    }
    if (-not [IO.File]::Exists($architecturePath)) {
        $areaLines = @($map.areas | ForEach-Object { "| $($_.id) | $($_.pathPattern) | $($_.layer) | $($_.owner) |" })
        $text = "# Proposed target architecture`n`nGuard review status: DRAFT`n`nThis draft was seeded from [inventory.json](inventory.json) and, when supplied, an existing profile. Review the prose and all structured JSON blocks against actual code. Edit the blocks to express desired policy; prose alone does not change generated configuration. Change status to REVIEWED only after inspection.`n`n## Areas to confirm`n`n| ID | Path | Layer | Owner |`n| --- | --- | --- | --- |`n$($areaLines -join "`n")`n`n## Profile identity`n`n$(Block 'profile.json' $profile)`n## Desired project map`n`n$(Block 'project-map.json' $map)`n## Desired stage rules`n`n"
        foreach ($name in @($rules.Keys | Sort-Object)) { $text += "### $name`n`n$(Block "rules/$name" $rules[$name])`n" }
        Write-Lf $architecturePath $text
    }
    if (-not [IO.File]::Exists($technicalPath)) {
        $commands = @($tech.commands | ForEach-Object { "| $($_.id) | $($_.executable) $(@($_.arguments) -join ' ') | $($_.workingDirectory) |" })
        $workflows = @($inventory.workflows | ForEach-Object { "- ``$($_.path)``" })
        $text = "# Proposed technical gate design`n`nGuard review status: DRAFT`n`nReview target languages, commands, .NET gate framework, existing CI and independent validators. Edit the structured block for machine configuration; describe detector limits and CI activation decisions in prose.`n`n## Candidate commands`n`n| ID | Command | Working directory |`n| --- | --- | --- |`n$($commands -join "`n")`n`n## Existing CI evidence`n`n$($workflows -join "`n")`n`n## Desired tech stack`n`n$(Block 'tech-stack.json' $tech)"
        Write-Lf $technicalPath $text
    }
    Write-Host "Architecture drafts ready (existing edits preserved): $architecturePath and $technicalPath"
    exit 0
}

foreach ($path in @($architecturePath, $technicalPath)) { if (-not [IO.File]::Exists($path)) { throw "Missing architecture draft: $path" } }
$architectureText = [IO.File]::ReadAllText($architecturePath)
$technicalText = [IO.File]::ReadAllText($technicalPath)
$statuses = @($architectureText, $technicalText | ForEach-Object {
    $m = [Regex]::Match($_, '(?m)^Guard review status: (DRAFT|REVIEWED)\s*$')
    if (-not $m.Success) { throw 'Each architecture document needs Guard review status: DRAFT or REVIEWED.' }
    $m.Groups[1].Value
})
$blocks = [ordered]@{}
foreach ($doc in @($architectureText, $technicalText)) {
    $matches = [Regex]::Matches((Lf $doc), '(?ms)^<!-- guard-config: (?<source>[^>]+) -->\n```json\n(?<json>.*?)\n```')
    foreach ($match in $matches) {
        $source = $match.Groups['source'].Value.Trim()
        if ($source -notin @('profile.json', 'project-map.json', 'tech-stack.json') -and $source -cnotmatch '^rules/[A-Z][A-Z0-9.-]+\.json$') { throw "Unsafe architecture block name: $source" }
        if ($blocks.Contains($source)) { throw "Duplicate architecture block: $source" }
        $schemaName = if ($source.StartsWith('rules/')) { 'rule' } else { [IO.Path]::GetFileNameWithoutExtension($source) }
        $jsonText = Lf $match.Groups['json'].Value
        if (-not (Test-Json -Json $jsonText -SchemaFile (Join-Path $packageRoot "contracts/$schemaName.schema.json") -ErrorAction Stop)) { throw "Architecture block violates $schemaName schema: $source" }
        $blocks[$source] = $jsonText
    }
}
foreach ($name in @('profile.json', 'project-map.json', 'tech-stack.json')) { if (-not $blocks.Contains($name)) { throw "Missing architecture block: $name" } }
$ruleNames = @($blocks.Keys | Where-Object { $_.StartsWith('rules/') } | Sort-Object)
if ($ruleNames.Count -eq 0) { throw 'Architecture document needs at least one rule block.' }
$proposalRoot = Join-Path $analysis 'review-profile'
$proposalRules = Join-Path $proposalRoot 'rules'
[void] [IO.Directory]::CreateDirectory($proposalRules)
foreach ($stale in @(Get-ChildItem -LiteralPath $proposalRules -File -Filter '*.json')) {
    if ("rules/$($stale.Name)" -notin $ruleNames) { Remove-Item -LiteralPath $stale.FullName -Force }
}
foreach ($name in $blocks.Keys) { Write-Lf (Join-Path $proposalRoot $name) $blocks[$name] }
Write-Lf (Join-Path $proposalRoot 'README.md') "# Generated architecture profile proposal`n`nThis directory is generated by Review from ARCHITECTURE.md and TECHNICAL.md. It is not an active profile or an accepted policy. Edit the source documents, rerun Review, and use explicit Adopt to create a new profile after review."
& (Join-Path $packageRoot 'commands/Invoke-V3.ps1') -Mode Validate -TargetRoot $root -ProfileDirectory $proposalRoot -OutputDirectory $analysis | Out-Null
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Proposed profile failed V3 validation.' }
$map = $blocks['project-map.json'] | ConvertFrom-Json -AsHashtable -Depth 100
$rules = @($ruleNames | ForEach-Object { $blocks[$_] | ConvertFrom-Json -AsHashtable -Depth 100 })
$sourceProjects = @($inventory.projects | Where-Object { $_.role -eq 'source' })
$unmapped = @($sourceProjects | Where-Object { $path = $_.path; @($map.areas | Where-Object { Match-Glob $path $_.pathPattern }).Count -eq 0 } | ForEach-Object { $_.path })
$unmatchedRules = @($rules | Where-Object {
    $rule = $_
    $rule.kind -eq 'forbidden-project-reference' -and @($sourceProjects | Where-Object { Match-Glob $_.path $rule.sourcePattern }).Count -eq 0
} | ForEach-Object { $_.id })
$violations = @()
foreach ($rule in @($rules | Where-Object { $_.kind -eq 'forbidden-project-reference' })) {
    foreach ($project in @($sourceProjects | Where-Object { Match-Glob $_.path $rule.sourcePattern })) {
        foreach ($reference in @($project.projectReferences)) {
            if ($reference.resolvedPath -and (Match-Glob $reference.resolvedPath $rule.forbiddenTargetPattern)) {
                $violations += [ordered]@{ ruleId = $rule.id; source = $project.path; target = $reference.resolvedPath }
            }
        }
    }
}
$profileDifferences = @()
if ($activeLayout) {
    $currentPaths = [ordered]@{ 'profile.json' = $activeLayout.Profile; 'project-map.json' = $activeLayout.ProjectMap; 'tech-stack.json' = $activeLayout.TechStack }
    foreach ($file in @(Get-ChildItem -LiteralPath $activeLayout.RulesDirectory -File -Filter '*.json')) { $currentPaths["rules/$($file.Name)"] = $file.FullName }
    foreach ($name in @(@($currentPaths.Keys) + @($blocks.Keys) | Sort-Object -Unique)) {
        $path = if ($currentPaths.Contains($name)) { $currentPaths[$name] } else { '' }
        if (-not [IO.File]::Exists($path) -or -not $blocks.Contains($name) -or (Canonical-Json ([IO.File]::ReadAllText($path))) -cne (Canonical-Json $blocks[$name])) { $profileDifferences += $name }
    }
}
foreach ($evidence in @($inventory.projects) + @($inventory.manifests) + @($inventory.workflows) + @($inventory.guidance)) {
    $file = Resolve-UnderRoot ([string] $evidence.path)
    if (-not [IO.File]::Exists($file) -or [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($file))).ToLowerInvariant() -ne $evidence.sha256) { throw "Inventory evidence is stale; rerun Analyze: $($evidence.path)" }
}
$reviewed = @($statuses | Where-Object { $_ -ne 'REVIEWED' }).Count -eq 0
$placeholders = @($map.areas | Where-Object { $_.owner -eq 'UNREVIEWED' -or $_.layer -eq 'UNREVIEWED' }).Count -gt 0 -or @($rules | Where-Object { $_.id -eq 'ARCH.UNCONFIGURED' }).Count -gt 0
$hasBlockingDetector = @($rules | Where-Object { $_.enforcement -eq 'blocking' -and $_.kind -ne 'none' }).Count -gt 0
$report = [ordered]@{
    formatVersion = 1; projectId = ($blocks['profile.json'] | ConvertFrom-Json).projectId
    documentReviewed = $reviewed; hasPlaceholders = $placeholders; hasBlockingDetector = $hasBlockingDetector
    profileDifferences = @($profileDifferences); unmappedSourceProjects = @($unmapped)
    unmatchedDetectorRules = @($unmatchedRules); observedForbiddenReferences = @($violations)
    proposalSha256 = Hash (@($blocks.Keys | Sort-Object | ForEach-Object { "$_`n$($blocks[$_])" }) -join '')
    decision = $(if (-not $reviewed -or $placeholders -or -not $hasBlockingDetector -or $unmatchedRules.Count -gt 0) { 'needs-review' } else { 'eligible-for-explicit-adoption' })
}
Write-Lf (Join-Path $analysis 'architecture-review.json') (Json $report)
$differenceLines = @($profileDifferences | ForEach-Object { "- ``$_``" })
$unmappedLines = @($unmapped | ForEach-Object { "- ``$_``" })
$violationLines = @($violations | ForEach-Object { "- $($_.ruleId): ``$($_.source)`` -> ``$($_.target)``" })
Write-Lf (Join-Path $analysis 'ARCHITECTURE-REVIEW.md') "# Architecture review`n`nDecision: **$($report.decision)**. Structured blocks are parsed; prose changes need an Agent or reviewer to translate them into those blocks before adoption. No current profile, independent policy or CI file was changed.`n`n- Project: $($report.projectId)`n- Reviewed documents: $reviewed`n- Placeholders: $placeholders`n- Blocking detector present: $hasBlockingDetector`n- Profile differences: $($profileDifferences.Count)`n- Unmapped source projects: $($unmapped.Count) (review whether they belong in scope)`n- Unmatched detector rules: $(if ($unmatchedRules.Count -eq 0) { '(none)' } else { $unmatchedRules -join ', ' })`n- Observed forbidden direct references: $($violations.Count)`n- Proposal SHA-256: ``$($report.proposalSha256)```n`n## Proposed profile differences`n`n$($differenceLines -join "`n")`n`n## Unmapped source projects`n`n$($unmappedLines -join "`n")`n`n## Observed forbidden references`n`n$($violationLines -join "`n")"
if ($Mode -eq 'Review') { Write-Host "Architecture review: $($report.decision). Report: $(Join-Path $analysis 'ARCHITECTURE-REVIEW.md')"; exit 0 }
if (-not $AcceptDocument) { throw 'Adopt requires -AcceptDocument after reviewing ARCHITECTURE-REVIEW.md.' }
if ($report.decision -ne 'eligible-for-explicit-adoption') { throw "Architecture proposal is not ready: $($report.decision)" }
if (-not $DestinationProfileDirectory) { throw 'Adopt requires DestinationProfileDirectory.' }
$destination = Resolve-UnderRoot $DestinationProfileDirectory
if ([IO.Directory]::Exists($destination) -or [IO.File]::Exists($destination)) { throw "Adopt refuses to overwrite an existing profile: $destination" }
[void] [IO.Directory]::CreateDirectory((Join-Path $destination 'rules'))
foreach ($name in $blocks.Keys) { Write-Lf (Join-Path $destination $name) $blocks[$name] }
Write-Lf (Join-Path $destination 'README.md') "# Adopted architecture profile`n`nCreated from reviewed ARCHITECTURE.md and TECHNICAL.md in ``$([IO.Path]::GetRelativePath($root, $evidence).Replace('\', '/'))``. Run Validate, Generate, Check and detector tests before using this profile as a merge gate. Independent policies and CI require separate review."
Write-Host "Adopted reviewed architecture to new profile: $destination"
