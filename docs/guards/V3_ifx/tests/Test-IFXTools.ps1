$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$profile = Join-Path $package 'profiles/ifx'
$inventoryRoot = Join-Path $package 'analysis/ifx'
$inventoryPath = Join-Path $inventoryRoot 'inventory.json'
$policyPath = Join-Path $package 'policy/layerguard.json'
$policyBefore = [IO.File]::ReadAllBytes($policyPath)
& (Join-Path $package 'scripts/Invoke-V3.ps1') -Mode Validate -TargetRoot $root -ProfileDirectory $profile -OutputDirectory (Join-Path $package 'generated/stages')
& (Join-Path $package 'scripts/Invoke-V3Docs.ps1') -Mode Check -TargetRoot $root -ProfileDirectory $profile
if (-not [IO.File]::Exists($inventoryPath)) { throw 'IFX inventory has not been generated.' }
$first = [IO.File]::ReadAllBytes($inventoryPath)
& (Join-Path $package 'scripts/Invoke-V3Setup.ps1') -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -ExcludePaths 'docs/guards/**'
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($inventoryPath))) { throw 'IFX analysis is not reproducible.' }
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $policyBefore, [byte[]] [IO.File]::ReadAllBytes($policyPath))) { throw 'Analyze modified independent LayerGuard policy.' }
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
if (@($inventory.projects | Where-Object { $_.role -eq 'source' }).Count -lt 40) { throw 'IFX source project inventory is incomplete.' }
if (@($inventory.projects | Where-Object { $_.path -eq 'mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj' }).Count -ne 1) { throw 'Existing LayerGuard project was not inventoried.' }
if (@($inventory.workflows | Where-Object { $_.path -eq '.github/workflows/layerguard.yml' }).Count -ne 1) { throw 'Existing LayerGuard CI workflow was not inventoried.' }
if ('src/Modules/CRM' -notin @($inventory.areaCandidates)) { throw 'IFX module candidate was not detected.' }
$coverage = [IO.File]::ReadAllText((Join-Path $profile 'views/COVERAGE.md'))
if ($coverage -notmatch '\[L2\.2\].*blocking' -or $coverage -notmatch '\[L2\.3\].*advisory') { throw 'IFX stage coverage view misstates enforcement.' }
Write-Host "IFX V3 tools passed: $($inventory.projects.Count) projects, $($inventory.workflows.Count) workflows, reproducible analysis, unchanged LayerGuard policy and checked Markdown views."
