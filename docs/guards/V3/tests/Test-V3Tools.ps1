$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$setup = Join-Path $package 'commands/Invoke-V3Setup.ps1'
$docs = Join-Path $package 'commands/Invoke-V3Docs.ps1'
$architecture = Join-Path $package 'scripts/Invoke-V3Architecture.ps1'
$guard = Join-Path $package 'commands/Invoke-V3.ps1'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$trial = Join-Path $tempRoot ('v3-tools-' + [Guid]::NewGuid().ToString('N'))
$generation = Join-Path $tempRoot ('v3-tools-generation-' + [Guid]::NewGuid().ToString('N'))
$trialPrefix = $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $trial.StartsWith($trialPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe trial directory.' }
$utf8 = [Text.UTF8Encoding]::new($false)
try {
    [void] [IO.Directory]::CreateDirectory((Join-Path $trial 'src/App'))
    [IO.File]::WriteAllText((Join-Path $trial 'src/App/App.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup><ItemGroup><ProjectReference Include="../Core/Core.csproj" /></ItemGroup></Project>', $utf8)
    [void] [IO.Directory]::CreateDirectory((Join-Path $trial '.github/workflows'))
    [IO.File]::WriteAllText((Join-Path $trial '.github/workflows/build.yml'), 'name: build', $utf8)
    & $setup -Mode Init -TargetRoot $trial -ProfileDirectory 'guard/profile' -ProjectId sample -TargetFramework net10.0
    & $guard -Mode Validate -TargetRoot $trial -ProfileDirectory 'guard/profile' -OutputDirectory 'guard/generated'
    $profile = Join-Path $trial 'guard/profile'
    $rulePath = Join-Path $profile 'rules/ARCH.UNCONFIGURED.json'
    $rule = Get-Content -LiteralPath $rulePath -Raw | ConvertFrom-Json
    if ($rule.enforcement -ne 'advisory' -or $rule.kind -ne 'none') { throw 'Init unexpectedly promoted an unreviewed rule.' }
    $pre = & pwsh -NoProfile -File $guard -Mode Pre -TargetRoot $trial -ProfileDirectory 'guard/profile' -PlannedPaths 'src/App/App.cs' -ReportPath 'guard/pre.json' 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'Unreviewed scaffold mapped a real source path.' }
    & $setup -Mode Analyze -TargetRoot $trial -OutputDirectory 'guard/analysis' -ExcludePaths 'guard/**'
    $inventoryPath = Join-Path $trial 'guard/analysis/inventory.json'
    $first = [IO.File]::ReadAllBytes($inventoryPath)
    $draftArchitecturePath = Join-Path $trial 'guard/analysis/ARCHITECTURE.md'
    $firstDraft = [IO.File]::ReadAllBytes($draftArchitecturePath)
    $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
    if ($inventory.projects.Count -ne 1 -or $inventory.workflows.Count -ne 1 -or $inventory.projects[0].projectReferences[0].resolvedPath -ne 'src/Core/Core.csproj') { throw 'Analyze missed repository evidence.' }
    & $setup -Mode Analyze -TargetRoot $trial -OutputDirectory 'guard/analysis' -ExcludePaths 'guard/**'
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($inventoryPath))) { throw 'Analyze output was not deterministic.' }
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $firstDraft, [byte[]] [IO.File]::ReadAllBytes($draftArchitecturePath))) { throw 'Analyze overwrote an editable architecture draft.' }
    $architecturePath = Join-Path $trial 'guard/analysis/ARCHITECTURE.md'
    $technicalPath = Join-Path $trial 'guard/analysis/TECHNICAL.md'
    if (-not [IO.File]::Exists($architecturePath) -or -not [IO.File]::Exists($technicalPath)) { throw 'Analyze did not create editable architecture drafts.' }
    & $architecture -Mode Review -TargetRoot $trial -AnalysisDirectory 'guard/analysis' -ProfileDirectory 'guard/profile'
    $draftReview = Get-Content -LiteralPath (Join-Path $trial 'guard/analysis/architecture-review.json') -Raw | ConvertFrom-Json
    if ($draftReview.decision -ne 'needs-review' -or -not $draftReview.hasPlaceholders) { throw 'Unreviewed architecture draft was treated as adoptable.' }
    $archText = [IO.File]::ReadAllText($architecturePath).Replace('Guard review status: DRAFT', 'Guard review status: REVIEWED').Replace('"layer": "UNREVIEWED"', '"layer": "application"').Replace('"owner": "UNREVIEWED"', '"owner": "sample-owner"')
    $sampleRule = [IO.File]::ReadAllText((Join-Path $package 'examples/minimal/rules/ARCH.SAMPLE.json')).TrimEnd("`r", "`n")
    $replacement = "<!-- guard-config: rules/ARCH.SAMPLE.json -->`n``````json`n$sampleRule`n``````"
    $archText = [Regex]::Replace($archText, '(?ms)<!-- guard-config: rules/ARCH\.UNCONFIGURED\.json -->\n```json\n.*?\n```', $replacement)
    [IO.File]::WriteAllText($architecturePath, $archText, $utf8)
    [IO.File]::WriteAllText($technicalPath, [IO.File]::ReadAllText($technicalPath).Replace('Guard review status: DRAFT', 'Guard review status: REVIEWED'), $utf8)
    & $architecture -Mode Review -TargetRoot $trial -AnalysisDirectory 'guard/analysis' -ProfileDirectory 'guard/profile'
    $reviewed = Get-Content -LiteralPath (Join-Path $trial 'guard/analysis/architecture-review.json') -Raw | ConvertFrom-Json
    if ($reviewed.decision -ne 'eligible-for-explicit-adoption' -or $reviewed.profileDifferences.Count -eq 0 -or $reviewed.observedForbiddenReferences.Count -ne 0) { throw 'Reviewed architecture comparison was incorrect.' }
    $projectPath = Join-Path $trial 'src/App/App.csproj'
    $originalProject = [IO.File]::ReadAllText($projectPath)
    try {
        [IO.File]::WriteAllText($projectPath, $originalProject + "`n<!-- changed after analysis -->`n", $utf8)
        $staleEvidence = $false
        try { & $architecture -Mode Review -TargetRoot $trial -AnalysisDirectory 'guard/analysis' -ProfileDirectory 'guard/profile' } catch { $staleEvidence = $_.Exception.Message -match 'Inventory evidence is stale' }
        if (-not $staleEvidence) { throw 'Architecture review accepted stale source evidence.' }
    }
    finally { [IO.File]::WriteAllText($projectPath, $originalProject, $utf8) }
    $confirmation = $false
    try { & $architecture -Mode Adopt -TargetRoot $trial -AnalysisDirectory 'guard/analysis' -DestinationProfileDirectory 'guard/adopted' } catch { $confirmation = $_.Exception.Message -match 'requires -AcceptDocument' }
    if (-not $confirmation) { throw 'Architecture adoption did not require explicit acceptance.' }
    & $architecture -Mode Adopt -TargetRoot $trial -AnalysisDirectory 'guard/analysis' -DestinationProfileDirectory 'guard/adopted' -AcceptDocument
    $generatedStage = Join-Path $generation 'sample/gates/stage'
    [void][IO.Directory]::CreateDirectory($generation)
    & $guard -Mode Validate -TargetRoot $trial -ProfileDirectory 'guard/adopted' -GenerationRoot $generation -PackageId sample -OutputDirectory $generatedStage -LockMode Update -LockRoot 'guard/locks'
    & $guard -Mode Generate -TargetRoot $trial -ProfileDirectory 'guard/adopted' -GenerationRoot $generation -PackageId sample -OutputDirectory $generatedStage -LockMode Update -LockRoot 'guard/locks'
    & $guard -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/adopted' -GenerationRoot $generation -PackageId sample -OutputDirectory $generatedStage -LockMode Update -LockRoot 'guard/locks'
    & $guard -Mode Test -TargetRoot $trial -ProfileDirectory 'guard/adopted' -GenerationRoot $generation -PackageId sample -OutputDirectory $generatedStage -LockMode Update -LockRoot 'guard/locks'
    $goodProject = [IO.File]::ReadAllText($projectPath)
    try {
        [IO.File]::WriteAllText($projectPath, $goodProject.Replace('../Core/Core.csproj', '../Legacy/Legacy.csproj'), $utf8)
        $badGate = @(& pwsh -NoProfile -File $guard -Mode Test -TargetRoot $trial -ProfileDirectory 'guard/adopted' -GenerationRoot $generation -PackageId sample -OutputDirectory $generatedStage -LockMode Update -LockRoot 'guard/locks' 2>&1)
        if ($LASTEXITCODE -eq 0 -or ($badGate -join ' | ') -notmatch 'ARCH.SAMPLE') { throw 'Adopted architecture gate accepted a deliberate forbidden reference.' }
    }
    finally { [IO.File]::WriteAllText($projectPath, $goodProject, $utf8) }
    & $docs -Mode Render -TargetRoot $trial -ProfileDirectory 'guard/profile'
    & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile'
    $view = Join-Path $profile 'views/rules/ARCH.UNCONFIGURED.md'
    $edited = [IO.File]::ReadAllText($view) + "`nmanual edit`n"
    [IO.File]::WriteAllText($view, $edited, $utf8)
    $drift = $false
    try { & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile' } catch { $drift = $_.Exception.Message -match 'Generated Markdown drift' }
    if (-not $drift) { throw 'Check did not detect edited Markdown.' }
    $importRejected = $false
    try { & $docs -Mode Import -TargetRoot $trial -ProfileDirectory 'guard/profile' } catch { $importRejected = $_.Exception.Message -match 'Import' }
    if (-not $importRejected) { throw 'Generated Markdown unexpectedly remained an import surface.' }
    if ((Get-Content -LiteralPath $rulePath -Raw | ConvertFrom-Json).title -ne 'Replace with reviewed target rules') { throw 'Editing generated Markdown changed JSON authority.' }
    & $docs -Mode Render -TargetRoot $trial -ProfileDirectory 'guard/profile'
    [IO.File]::WriteAllText((Join-Path $profile 'views/rules/STALE.md'), 'stale', $utf8)
    $extra = $false
    try { & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile' } catch { $extra = $_.Exception.Message -match 'Unexpected generated Markdown' }
    if (-not $extra) { throw 'Check did not detect an extra view.' }
    & $docs -Mode Render -TargetRoot $trial -ProfileDirectory 'guard/profile'
    & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile'
    if ([IO.File]::ReadAllText($view) -notmatch 'GENERATED READ-ONLY' -or [IO.File]::ReadAllText($view) -match '```json') { throw 'Generated profile view is not unambiguously read-only.' }
    Write-Host 'V3 setup/docs tests passed: fail-closed Init, evidence inventory, architecture review/adoption, generated positive/negative gate, and read-only Markdown drift checks.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($trial)
    if (-not $resolved.StartsWith($trialPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe trial cleanup path.' }
    if ([IO.Directory]::Exists($resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    if ([IO.Directory]::Exists($generation)) { Remove-Item -LiteralPath $generation -Recurse -Force }
}
