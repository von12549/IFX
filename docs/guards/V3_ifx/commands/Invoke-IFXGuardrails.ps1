[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate','Pre','Diff','Architecture','Specialized','Quality','HistoricalIntegrity','Scope','CandidateTests','TrustedComponentCandidate','All')][string] $Mode,
    [string] $TargetRoot,
    [switch] $TrustedBase,
    [string] $BaseSha,
    [string] $GateId,
    [string] $GitHubOutput,
    [ValidateSet('Architecture','CrossPlatform')][string] $CandidateSuite,
    [ValidateSet('smoke','full')][string] $CandidateCoverage = 'full',
    [ValidateSet('G03','G04','G05','Plan04','Database','All')][string] $SpecializedGate = 'All',
    [ValidateSet('Solution','Assembly','Frontend','All')][string] $QualityTarget = 'All',
    [string] $PlanPath,
    [string[]] $PlannedPaths = @(),
    [string] $BaseRef,
    [string] $HeadRef,
    [string] $GenerationRoot,
    [string] $OutputDirectory = 'artifacts/guards/v3-ifx'
)

$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
# Package code, configuration and generated projects come from the repository this package runs from; target data
# comes from TargetRoot. In-place runs use one repository for both (Plan 06 P2 root separation).
$packageRepository = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$root = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { $packageRepository }
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must stay under TargetRoot.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$started = [DateTimeOffset]::UtcNow
$checks = @()

function Resolve-PolicyRelativeRoot([string] $PackageRoot) {
    $available = @('policy', 'stages/post/policy' | Where-Object { Test-Path -LiteralPath (Join-Path $PackageRoot "$_/layerguard.json") -PathType Leaf })
    if ($available.Count -ne 1) { throw "Exactly one complete legacy or stage-owned policy layout must exist; found $($available.Count)." }
    return $available[0]
}
function Resolve-AuthorityRegistryRelativePath([string] $PackageRoot) {
    $available = @(@('policy/authorities.json', 'shared/authorities/authorities.json') | Where-Object { Test-Path -LiteralPath (Join-Path $PackageRoot $_) -PathType Leaf })
    if ($available.Count -ne 1) { throw "Exactly one legacy or shared authority registry must exist; found $($available.Count)." }
    return $available[0]
}
function Resolve-IFXContractPath([string] $PackageRoot, [string] $relative) {
    $available = @(@("contracts/$relative", "shared/contracts/$relative") | ForEach-Object { Join-Path $PackageRoot $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($available.Count -ne 1) { throw "Exactly one legacy or shared contract must exist for $relative; found $($available.Count)." }
    return $available[0]
}
$policyRelativeRoot = Resolve-PolicyRelativeRoot $packageRoot
$authorityRegistryRelativePath = Resolve-AuthorityRegistryRelativePath $packageRoot

function Relative([string] $path) { [IO.Path]::GetRelativePath($root, $path).Replace('\','/') }
function Invoke-Child([string] $id, [string] $script, [string[]] $arguments, [string[]] $evidence) {
    try {
        & pwsh -NoProfile -File $script @arguments
        if ($LASTEXITCODE -ne 0) { throw "$id returned exit code $LASTEXITCODE." }
        foreach ($path in $evidence) {
            $full = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$id did not produce required evidence: $path" }
        }
        $script:checks += [ordered]@{ id = $id; status = 'pass'; reason = $null; evidencePaths = @($evidence) }
    } catch {
        $script:checks += [ordered]@{ id = $id; status = 'fail'; reason = $_.Exception.Message; evidencePaths = @($evidence) }
    }
}

# CI calls only this public façade. TrustedBase forwards into the base-owned internal runner; the candidate modes
# keep supplemental head tests and TCB verification behind the same stable command boundary (Plan 06 P9).
if ($TrustedBase) {
    if (-not $BaseSha) { throw '-TrustedBase requires -BaseSha.' }
    if ($Mode -notin @('Validate','Pre','Diff','Architecture','Specialized','Quality','HistoricalIntegrity','Scope')) { throw "Mode $Mode is not available with -TrustedBase." }
    $arguments = @('-HeadRoot', $root, '-BaseSha', $BaseSha, '-Mode', $Mode, '-OutputDirectory', $OutputDirectory)
    foreach ($pair in @(
        @('SpecializedGate', $SpecializedGate),
        @('QualityTarget', $QualityTarget),
        @('PlanPath', $PlanPath),
        @('BaseRef', $BaseRef),
        @('HeadRef', $HeadRef),
        @('GenerationRoot', $GenerationRoot),
        @('GateId', $GateId),
        @('GitHubOutput', $GitHubOutput)
    )) { if (-not [string]::IsNullOrWhiteSpace([string]$pair[1])) { $arguments += @("-$($pair[0])", [string]$pair[1]) } }
    & pwsh -NoProfile -File (Join-Path $packageRoot 'trusted-base/Invoke-IFXTrustedBase.ps1') @arguments
    exit $LASTEXITCODE
}

if ($Mode -eq 'TrustedComponentCandidate') {
    if (-not $BaseSha) { throw 'TrustedComponentCandidate requires -BaseSha.' }
    & pwsh -NoProfile -File (Join-Path $packageRoot 'trusted-base/Test-IFXTrustedBaseCandidate.ps1') -TargetRoot $root -BaseSha $BaseSha
    exit $LASTEXITCODE
}

if ($Mode -eq 'CandidateTests') {
    if (-not $CandidateSuite) { throw 'CandidateTests requires -CandidateSuite.' }
    if ($CandidateSuite -ne 'CrossPlatform' -and $CandidateCoverage -ne 'full') { throw 'CandidateCoverage is only available for the CrossPlatform candidate suite.' }
    if ($CandidateSuite -eq 'CrossPlatform' -and -not $GenerationRoot) { throw 'CrossPlatform candidate tests require -GenerationRoot.' }
    $candidateStage = if ($GenerationRoot) { Join-Path ([IO.Path]::GetFullPath($GenerationRoot)) 'v3-ifx/gates/stage' } else { $null }
    $architectureCommands = @(
        ,@('docs/guards/V3_ifx/tests/pre/Test-IFXPre.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXAssemblyGuard.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXAuthorityProjection.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXSpecializedContracts.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXHistoricalIntegrity.ps1')
        ,@('docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXPackage.ps1')
        ,@('docs/guards/V3_ifx/tests/ci/Test-IFXCiContract.ps1')
        ,@('docs/guards/V3_ifx/tests/ci/Test-IFXDeployment.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXManifests.ps1')
        ,@('docs/guards/V3/tests/Test-V3ArchUnit.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTrustedBase.ps1', '-ArchitectureOnly')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTrustedBase.ps1', '-DiffConsumptionOnly')
    )
    # BEGIN FULL CROSS-PLATFORM CANDIDATE SUITE
    $fullCrossPlatformCommands = @(
        ,@('docs/guards/V3/commands/Invoke-V3.ps1', '-Mode', 'Generate', '-ProfileLayoutPath', 'docs/guards/V3_ifx/shared/profile-layout.json', '-ProfileRepositoryRoot', $packageRepository, '-TargetRoot', $root, '-GenerationRoot', $GenerationRoot, '-PackageId', 'v3-ifx', '-OutputDirectory', $candidateStage)
        ,@('docs/guards/V3/commands/Invoke-V3.ps1', '-Mode', 'Check', '-ProfileLayoutPath', 'docs/guards/V3_ifx/shared/profile-layout.json', '-ProfileRepositoryRoot', $packageRepository, '-TargetRoot', $root, '-GenerationRoot', $GenerationRoot, '-PackageId', 'v3-ifx', '-OutputDirectory', $candidateStage)
        ,@('docs/guards/V3_ifx/commands/Invoke-IFXArchitecture.ps1', '-Mode', 'Generate')
        ,@('docs/guards/V3_ifx/commands/Invoke-IFXArchitecture.ps1', '-Mode', 'Check')
        ,@('docs/guards/V3/tests/Test-V3.ps1')
        ,@('docs/guards/V3/tests/Test-V3BuildBaseline.ps1')
        ,@('docs/guards/V3_ifx/tests/pre/Test-IFXPre.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXAuthorityProjection.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXSpecializedContracts.ps1')
        ,@('docs/guards/V3_ifx/tests/post/Test-IFXHistoricalIntegrity.ps1')
        ,@('docs/guards/V3_ifx/tests/ci/Test-IFXDeployment.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTargetRootSeparation.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXDomainAuthorityCandidates.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTrustedBase.ps1')
    )
    # END FULL CROSS-PLATFORM CANDIDATE SUITE
    # BEGIN WINDOWS PORTABILITY SMOKE
    $windowsPortabilitySmokeCommands = @(
        ,@('docs/guards/V3/commands/Invoke-V3.ps1', '-Mode', 'Generate', '-ProfileLayoutPath', 'docs/guards/V3_ifx/shared/profile-layout.json', '-ProfileRepositoryRoot', $packageRepository, '-TargetRoot', $root, '-GenerationRoot', $GenerationRoot, '-PackageId', 'v3-ifx', '-OutputDirectory', $candidateStage)
        ,@('docs/guards/V3/commands/Invoke-V3.ps1', '-Mode', 'Check', '-ProfileLayoutPath', 'docs/guards/V3_ifx/shared/profile-layout.json', '-ProfileRepositoryRoot', $packageRepository, '-TargetRoot', $root, '-GenerationRoot', $GenerationRoot, '-PackageId', 'v3-ifx', '-OutputDirectory', $candidateStage)
        ,@('docs/guards/V3_ifx/commands/Invoke-IFXArchitecture.ps1', '-Mode', 'Generate')
        ,@('docs/guards/V3_ifx/commands/Invoke-IFXArchitecture.ps1', '-Mode', 'Check')
        ,@('docs/guards/V3/tests/Test-V3BuildBaseline.ps1')
        ,@('docs/guards/V3_ifx/tests/support/Test-IFXTargetRootSeparation.ps1')
    )
    # END WINDOWS PORTABILITY SMOKE
    $testCommands = if ($CandidateSuite -eq 'Architecture') {
        $architectureCommands
    } elseif ($CandidateCoverage -eq 'smoke') {
        $windowsPortabilitySmokeCommands
    } else {
        $fullCrossPlatformCommands
    }
    foreach ($command in $testCommands) {
        $script = [IO.Path]::GetFullPath((Join-Path $packageRepository $command[0]))
        [string[]] $arguments = @()
        if ($command.Count -gt 1) { $arguments = [string[]]@($command | Select-Object -Skip 1) }
        & pwsh -NoProfile -File $script @arguments
        if ($LASTEXITCODE) { throw "$($command -join ' ') failed with exit code $LASTEXITCODE." }
    }
    Write-Host "IFX $CandidateSuite candidate tests passed."
    exit 0
}

$profileLayout = Join-Path $packageRoot 'shared/profile-layout.json'
$v3 = Join-Path $packageRepository 'docs/guards/V3/commands/Invoke-V3.ps1'
$architecture = Join-Path $PSScriptRoot 'Invoke-IFXArchitecture.ps1'
$specialized = Join-Path $packageRoot 'stages/post/gates/specialized/Invoke-IFXSpecialized.ps1'
$quality = Join-Path $packageRoot 'stages/post/gates/quality/Invoke-IFXQuality.ps1'
$history = Join-Path $packageRoot 'stages/post/gates/historical-integrity/Invoke-IFXHistoricalIntegrity.ps1'
$docs = Join-Path $packageRepository 'docs/guards/V3/commands/Invoke-V3Docs.ps1'
$ciContract = Join-Path $PSScriptRoot 'Invoke-IFXCiContract.ps1'
$manifestCheck = Join-Path $PSScriptRoot '../engine/Invoke-IFXManifestCheck.ps1'
$modes = if ($Mode -eq 'All') { @('Validate','Architecture','Specialized','Quality','HistoricalIntegrity') } else { @($Mode) }

foreach ($current in $modes) {
    switch ($current) {
        'Validate' {
            Invoke-Child 'profile-validate' $v3 @('-Mode','Validate','-ProfileLayoutPath',$profileLayout,'-ProfileRepositoryRoot',$packageRepository,'-TargetRoot',$root,'-GenerationRoot',$packageRepository) @()
            Invoke-Child 'architecture-input-validate' $architecture @('-Mode','Validate','-TargetRoot',$root) @()
            Invoke-Child 'profile-views' $docs @('-Mode','Check','-ProfileLayoutPath',$profileLayout,'-ProfileRepositoryRoot',$packageRepository,'-TargetRoot',$packageRepository,'-PackageDirectory',$packageRoot) @()
            Invoke-Child 'ci-contract' $ciContract @('-TargetRoot',$root) @()
            Invoke-Child 'manifest-check' $manifestCheck @('-TargetRoot',$root) @()
        }
        'Pre' {
            $report = Join-Path $output 'pre.json'
            $args = @('-Mode','Pre','-ProfileLayoutPath',$profileLayout,'-ProfileRepositoryRoot',$packageRepository,'-TargetRoot',$root,'-GenerationRoot',$packageRepository,'-ReportPath',(Relative $report))
            if ($PlanPath) { $args += @('-PlanPath',$PlanPath) } else { $args += @('-PlannedPaths') + $PlannedPaths }
            Invoke-Child 'pre' $v3 $args @((Relative $report))
        }
        'Diff' {
            $ownsGenerationRoot = -not $GenerationRoot
            $generation = [IO.Path]::GetFullPath($(if ($GenerationRoot) { $GenerationRoot } else {
                Join-Path ([IO.Path]::GetTempPath()) "guard-gen-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
            }))
            $generatedStages = Join-Path $generation 'v3-ifx/gates/stage'
            try {
                [void][IO.Directory]::CreateDirectory($generation)
                $common = @('-ProfileLayoutPath',$profileLayout,'-ProfileRepositoryRoot',$packageRepository,'-TargetRoot',$root,'-GenerationRoot',$generation,'-PackageId','v3-ifx','-OutputDirectory',$generatedStages,'-LockRoot',(Join-Path $packageRoot 'build/locks'),'-ProtectionPath',(Join-Path $packageRoot 'stages/diff/protection.json'))
                Invoke-Child 'stage-gate-generate' $v3 (@('-Mode','Generate') + $common) @()
                Invoke-Child 'stage-gate-check' $v3 (@('-Mode','Check') + $common) @()
                $args = @('-Mode','Diff') + $common + @('-PlanPath',$PlanPath,'-BaseRef',$BaseRef)
                if ($HeadRef) { $args += @('-HeadRef',$HeadRef) }
                Invoke-Child 'diff' $v3 $args @()
            }
            finally {
                if ($ownsGenerationRoot -and [IO.Directory]::Exists($generation)) { [IO.Directory]::Delete($generation, $true) }
            }
        }
        'Architecture' {
            $report = Join-Path $output 'architecture/layerguard.json'
            Invoke-Child 'architecture' $architecture @('-Mode','Test','-TargetRoot',$root,'-ReportPath',(Relative $report)) @((Relative $report))
        }
        'Specialized' {
            $directory = Join-Path $output 'specialized'
            Invoke-Child "specialized-$($SpecializedGate.ToLowerInvariant())" $specialized @('-Gate',$SpecializedGate,'-TargetRoot',$root,'-OutputDirectory',(Relative $directory)) @((Relative (Join-Path $directory 'summary.json')))
        }
        'Quality' {
            $directory = Join-Path $output 'quality'
            Invoke-Child "quality-$($QualityTarget.ToLowerInvariant())" $quality @('-Target',$QualityTarget,'-TargetRoot',$root,'-OutputDirectory',(Relative $directory)) @((Relative (Join-Path $directory 'summary.json')))
        }
        'HistoricalIntegrity' {
            $report = Join-Path $output 'history/summary.json'
            Invoke-Child 'historical-integrity' $history @('-RepositoryRoot',$root,'-ReportPath',(Relative $report)) @((Relative $report))
        }
    }
}

$inputBuilder = [Text.StringBuilder]::new()
foreach ($relative in @('shared/profile-layout.json','shared/profile.json','stages/pre/project-map.json','shared/toolchain.json',$authorityRegistryRelativePath,"$policyRelativeRoot/layerguard.json",'stages/post/gates/historical-integrity/manifest.json')) {
    $path = Join-Path $packageRoot $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        [void]$inputBuilder.Append($relative).Append("`n").Append(([IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")))
    }
}
$inputHash = ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($inputBuilder.ToString())))).ToLowerInvariant()

$summaryMode = switch ($Mode) {
    'HistoricalIntegrity' { 'historical-integrity' }
    default { $Mode.ToLowerInvariant() }
}
$summary = [ordered]@{
    formatVersion = 1
    mode = $summaryMode
    status = if (@($checks | Where-Object status -in @('fail','blocked')).Count -eq 0) { 'pass' } else { 'fail' }
    startedAt = $started.ToString('O')
    completedAt = [DateTimeOffset]::UtcNow.ToString('O')
    inputHash = $inputHash
    reason = if (@($checks | Where-Object status -in @('fail','blocked')).Count -eq 0) { $null } else { 'One or more blocking guard checks failed.' }
    checks = $checks
}
$summaryPath = Join-Path $output "summary-$summaryMode.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if (-not (Test-Json -LiteralPath $summaryPath -SchemaFile (Resolve-IFXContractPath $packageRoot 'guard-summary.schema.json') -ErrorAction Stop)) { throw 'Unified summary does not match guard-summary.schema.json.' }
if ($summary.status -ne 'pass') { throw "IFX guardrails failed: $summaryPath" }
Write-Host "IFX guardrails passed: $summaryPath"
