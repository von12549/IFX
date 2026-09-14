$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$profile = Join-Path $package 'profiles/ifx'
$inventoryRoot = Join-Path $package 'analysis/ifx'
$inventoryPath = Join-Path $inventoryRoot 'inventory.json'
$architecturePath = Join-Path $inventoryRoot 'ARCHITECTURE.md'
$technicalPath = Join-Path $inventoryRoot 'TECHNICAL.md'
$policyPath = Join-Path $package 'policy/layerguard.json'
$policyBefore = [IO.File]::ReadAllBytes($policyPath)
$profileBefore = @(Get-ChildItem -LiteralPath $profile -File -Recurse | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($profile, $_.FullName)):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
& (Join-Path $package 'scripts/Invoke-V3.ps1') -Mode Validate -TargetRoot $root -ProfileDirectory $profile -OutputDirectory (Join-Path $package 'generated/stages')
& (Join-Path $package 'scripts/Invoke-V3Docs.ps1') -Mode Check -TargetRoot $root -ProfileDirectory $profile
if (-not [IO.File]::Exists($inventoryPath)) { throw 'IFX inventory has not been generated.' }
$first = [IO.File]::ReadAllBytes($inventoryPath)
$architectureBefore = [IO.File]::ReadAllBytes($architecturePath)
$technicalBefore = [IO.File]::ReadAllBytes($technicalPath)
& (Join-Path $package 'scripts/Invoke-V3Setup.ps1') -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -ProfileDirectory $profile -ExcludePaths 'docs/guards/**'
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($inventoryPath))) { throw 'IFX analysis is not reproducible.' }
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $architectureBefore, [byte[]] [IO.File]::ReadAllBytes($architecturePath)) -or
    -not [Linq.Enumerable]::SequenceEqual([byte[]] $technicalBefore, [byte[]] [IO.File]::ReadAllBytes($technicalPath))) { throw 'Analyze overwrote editable IFX architecture drafts.' }
& (Join-Path $package 'scripts/Invoke-V3Architecture.ps1') -Mode Review -TargetRoot $root -AnalysisDirectory $inventoryRoot -ProfileDirectory $profile
$review = Get-Content -LiteralPath (Join-Path $inventoryRoot 'architecture-review.json') -Raw | ConvertFrom-Json
if ($review.projectId -ne 'ifx' -or $review.documentReviewed -or $review.profileDifferences.Count -ne 0 -or -not $review.hasBlockingDetector -or $review.observedForbiddenReferences.Count -ne 0) { throw 'IFX architecture review does not match current evidence/profile.' }
$profileAfter = @(Get-ChildItem -LiteralPath $profile -File -Recurse | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($profile, $_.FullName)):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
if (@(Compare-Object $profileBefore $profileAfter).Count -ne 0) { throw 'Architecture review modified the current IFX profile.' }
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $policyBefore, [byte[]] [IO.File]::ReadAllBytes($policyPath))) { throw 'Analyze modified independent LayerGuard policy.' }
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
if (@($inventory.projects | Where-Object { $_.role -eq 'source' }).Count -lt 40) { throw 'IFX source project inventory is incomplete.' }
if (@($inventory.projects | Where-Object { $_.path -eq 'mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj' }).Count -ne 1) { throw 'Existing LayerGuard project was not inventoried.' }
if (@($inventory.workflows | Where-Object { $_.path -eq '.github/workflows/layerguard.yml' }).Count -ne 1) { throw 'Existing LayerGuard CI workflow was not inventoried.' }
if ('src/Modules/CRM' -notin @($inventory.areaCandidates)) { throw 'IFX module candidate was not detected.' }
$coverage = [IO.File]::ReadAllText((Join-Path $profile 'views/COVERAGE.md'))
if ($coverage -notmatch '\[L2\.2\].*blocking' -or $coverage -notmatch '\[L2\.3\].*advisory') { throw 'IFX stage coverage view misstates enforcement.' }
Write-Host "IFX V3 tools passed: $($inventory.projects.Count) projects, $($inventory.workflows.Count) workflows, reproducible analysis, preserved architecture drafts, zero profile drift, unchanged LayerGuard policy and checked Markdown views."
