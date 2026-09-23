param([string] $RepositoryRoot = (Get-Location).Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$candidate = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1m/Test-IFXApplicability.ps1'
$decisionRelative = 'docs/guards/inventories/20260924-ifx-c1-applicability-decisions.json'
$decision = Get-Content -LiteralPath (Join-Path $repo $decisionRelative) -Raw | ConvertFrom-Json -Depth 30
$fixtureRoot = Join-Path $repo ('artifacts/guards/p10-ifx-c1m/tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

function Invoke-Case([string] $Name, [string] $AuthorityRoot, [string] $TargetRoot, [int] $ExitCode, [string] $Category) {
    $output = & pwsh -NoProfile -File $candidate -RepositoryRoot $AuthorityRoot -TargetRoot $TargetRoot 2>&1
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExitCode) { throw "$Name exit $actualExit; expected $ExitCode. $output" }
    $result = [string](@($output)[-1]) | ConvertFrom-Json
    if ($Category -and $result.category -cne $Category) { throw "$Name category $($result.category); expected $Category." }
    if (-not $Category -and $result.status -cne 'pass') { throw "$Name did not pass." }
    Write-Output "$Name PASS"
}

Invoke-Case 'real-clean' $repo $repo 0 ''
$target = Join-Path $fixtureRoot 'target'
foreach ($project in @($decision.integrationAdapter.projects)) {
    $destination = Join-Path $target ([string]$project.path)
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo ([string]$project.path)) -Destination $destination
}
Invoke-Case 'frozen-fixture-clean' $repo $target 0 ''
$first = Join-Path $target ([string]$decision.integrationAdapter.projects[0].path)
Add-Content -LiteralPath $first -Value '<!-- changed -->'
Invoke-Case 'modified-project' $repo $target 1 'inventory-drift'
Copy-Item -LiteralPath (Join-Path $repo ([string]$decision.integrationAdapter.projects[0].path)) -Destination $first -Force
$extra = Join-Path $target 'src/Modules/New/IFX.Modules.New.Integration/IFX.Modules.New.Integration.csproj'
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($extra)) -Force | Out-Null
Set-Content -LiteralPath $extra -Value '<Project Sdk="Microsoft.NET.Sdk" />'
Invoke-Case 'adapter-added' $repo $target 1 'adapter-present'
Remove-Item -LiteralPath $extra
$extra = Join-Path $target 'src/Modules/New/IFX.Modules.New.Domain/IFX.Modules.New.Domain.csproj'
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($extra)) -Force | Out-Null
Set-Content -LiteralPath $extra -Value '<Project Sdk="Microsoft.NET.Sdk" />'
Invoke-Case 'nonadapter-project-added' $repo $target 1 'inventory-drift'
Remove-Item -LiteralPath $extra
$second = Join-Path $target ([string]$decision.integrationAdapter.projects[1].path)
Remove-Item -LiteralPath $second
Invoke-Case 'project-removed' $repo $target 1 'inventory-drift'
$empty = Join-Path $fixtureRoot 'empty'
New-Item -ItemType Directory -Path $empty | Out-Null
Invoke-Case 'src-missing' $repo $empty 1 'prerequisite-missing'
New-Item -ItemType Directory -Path (Join-Path $empty 'src') | Out-Null
Invoke-Case 'zero-projects' $repo $empty 1 'inventory-drift'

$authority = Join-Path $fixtureRoot 'authority'
foreach ($item in @($decision.l29.authority)) {
    $destination = Join-Path $authority ([string]$item.path)
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo ([string]$item.path)) -Destination $destination
}
$decisionDestination = Join-Path $authority $decisionRelative
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($decisionDestination)) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo $decisionRelative) -Destination $decisionDestination
Invoke-Case 'authority-copy-clean' $authority $repo 0 ''
Add-Content -LiteralPath (Join-Path $authority ([string]$decision.l29.authority[2].path)) -Value '// drift'
Invoke-Case 'source-drift' $authority $repo 1 'authority-drift'
Write-Output "Evidence: $fixtureRoot"
