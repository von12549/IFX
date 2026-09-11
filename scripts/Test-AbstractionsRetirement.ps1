[CmdletBinding()]
param([string] $StatusPath = 'docs/architecture/review/evidence/plan04/abstractions-retirement-status.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path }; Join-Path $repositoryRoot $path }
function SetsEqual([object[]] $left, [object[]] $right) { (@($left | Sort-Object) -join '|') -eq (@($right | Sort-Object) -join '|') }

$legacyProjectPattern = '^IFX\.(Modules|Platform)\..+\.Abstractions$'
$requiredContracts = @(
    'IFX.Modules.CRM.Contracts',
    'IFX.Modules.Registry.Contracts',
    'IFX.Modules.Transaction.Contracts',
    'IFX.Platform.BackgroundJobs.Contracts',
    'IFX.Platform.Context.Contracts',
    'IFX.Platform.Messaging.Contracts',
    'IFX.Platform.Notifications.Contracts'
)

function ValidateState([object] $state) {
    $errors = [Collections.Generic.HashSet[string]]::new()
    if (@($state.directories | Where-Object { [IO.Path]::GetFileName([string]$_) -match $legacyProjectPattern }).Count -gt 0) { [void]$errors.Add('legacy-abstractions-directory') }
    if (@($state.projects | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern }).Count -gt 0) { [void]$errors.Add('legacy-abstractions-project') }
    if (@($state.projectReferences | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern }).Count -gt 0) { [void]$errors.Add('legacy-abstractions-reference') }
    if (@($state.solutionProjects | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern }).Count -gt 0) { [void]$errors.Add('legacy-abstractions-solution-entry') }
    if (@($requiredContracts | Where-Object { $_ -notin @($state.solutionProjects | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) }) }).Count -gt 0) { [void]$errors.Add('contracts-project-missing-from-solution') }
    if ($state.layerGuardEnforcesRetirement -ne $true) { [void]$errors.Add('layerguard-retirement-rule-missing') }
    @($errors | Sort-Object)
}

$solutionText = Get-Content -Raw -LiteralPath (Repo 'IFX.sln')
$solutionProjects = @([regex]::Matches($solutionText, '(?m)^Project\("[^"]+"\) = "[^"]+", "([^"]+\.csproj)"') | ForEach-Object { $_.Groups[1].Value })
$searchRoots = @('src/Modules', 'src/Platform') | ForEach-Object { Repo $_ }
$directories = @($searchRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Recurse } | Where-Object Name -Match $legacyProjectPattern | ForEach-Object FullName)
$projects = @($searchRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse -Filter '*.csproj' } | ForEach-Object FullName)
$projectReferences = @(
    @('src', 'tests') | ForEach-Object {
        Get-ChildItem -LiteralPath (Repo $_) -File -Recurse -Filter '*.csproj' | ForEach-Object {
            $projectFile = $_
            [xml]$projectXml = Get-Content -Raw -LiteralPath $projectFile.FullName
            @($projectXml.Project.ItemGroup.ProjectReference) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.Include }
        }
    }
)
$layerGuard = Get-Content -Raw -LiteralPath (Repo 'src/layerguard.json') | ConvertFrom-Json -Depth 100
$layerGuardEnforcesRetirement = '*.Abstractions' -in @($layerGuard.forbiddenProjectNames) -and @($layerGuard.ruleRefs | Where-Object { $_.ref -eq 'L1.2' -and 'PROJECT-NAME-FORBIDDEN' -in @($_.rules) }).Count -eq 1
$repositoryState = [ordered]@{
    directories = $directories
    projects = $projects
    projectReferences = $projectReferences
    solutionProjects = $solutionProjects
    layerGuardEnforcesRetirement = $layerGuardEnforcesRetirement
}
$repositoryErrors = @(ValidateState $repositoryState)
$missingContracts = @($requiredContracts | Where-Object { $_ -notin @($solutionProjects | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) }) })

$fixtureResults = @()
foreach ($file in @(Get-ChildItem -LiteralPath (Repo 'tests/Architecture/Plan04/Fixtures') -File -Filter 'abstractions-*.json' | Sort-Object Name)) {
    $fixture = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 100
    $actual = @(ValidateState $fixture)
    $expected = @($fixture.expectedErrors | Sort-Object)
    $fixtureResults += [ordered]@{ fixture = $file.Name; expectedErrors = $expected; actualErrors = $actual; passed = SetsEqual $expected $actual }
}

$checks = [ordered]@{
    noLegacyAbstractionsDirectories = @($repositoryErrors | Where-Object { $_ -eq 'legacy-abstractions-directory' }).Count -eq 0
    noLegacyAbstractionsProjects = @($repositoryErrors | Where-Object { $_ -eq 'legacy-abstractions-project' }).Count -eq 0
    noLegacyAbstractionsReferences = @($repositoryErrors | Where-Object { $_ -eq 'legacy-abstractions-reference' }).Count -eq 0
    noLegacyAbstractionsSolutionEntries = @($repositoryErrors | Where-Object { $_ -eq 'legacy-abstractions-solution-entry' }).Count -eq 0
    requiredContractsAreExplicitSolutionProjects = $missingContracts.Count -eq 0
    layerGuardRetirementRuleIsBound = $layerGuardEnforcesRetirement
    positiveAndNegativeFixturesPass = $fixtureResults.Count -eq 4 -and @($fixtureResults | Where-Object passed -ne $true).Count -eq 0 -and @($fixtureResults | Where-Object { @($_.actualErrors).Count -eq 0 }).Count -eq 1
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    result = if ($failed.Count -eq 0) { 'repository-passed-legacy-abstractions-retired' } else { 'failed' }
    checks = $checks
    legacyDirectories = $directories
    legacyProjects = @($projects | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern })
    legacyProjectReferences = @($projectReferences | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern })
    legacySolutionEntries = @($solutionProjects | Where-Object { [IO.Path]::GetFileNameWithoutExtension([string]$_) -match $legacyProjectPattern })
    requiredContracts = $requiredContracts
    missingContracts = $missingContracts
    fixtureResults = $fixtureResults
    exclusions = @('App.Abstractions composition SPI (renamed separately)', 'IFX.BuildingBlocks.Security.Authorization.Abstractions namespace (renamed separately)', 'Microsoft.Extensions.*.Abstractions packages', 'G03 retired identity reservations', 'LayerGuard fixtures and historical baselines')
    failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$directory = Split-Path -Parent $resolvedStatus
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$status | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Abstractions retirement validation failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Abstractions retirement result: $($status.result). Report: $resolvedStatus"
