[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate','Pre','Diff','Architecture','Specialized','Quality','HistoricalIntegrity','All')][string] $Mode,
    [string] $TargetRoot,
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

$profile = Join-Path $packageRoot 'profiles/ifx'
$v3 = Join-Path $packageRepository 'docs/guards/V3/scripts/Invoke-V3.ps1'
$architecture = Join-Path $PSScriptRoot 'Invoke-IFX.ps1'
$specialized = Join-Path $packageRoot 'specialized/Invoke-IFXSpecialized.ps1'
$quality = Join-Path $packageRoot 'quality/Invoke-IFXQuality.ps1'
$history = Join-Path $packageRoot 'history/Invoke-IFXHistoricalIntegrity.ps1'
$docs = Join-Path $packageRepository 'docs/guards/V3/scripts/Invoke-V3Docs.ps1'
$ciContract = Join-Path $packageRoot 'ci/Invoke-IFXCiContract.ps1'
$manifestCheck = Join-Path $PSScriptRoot 'Invoke-IFXManifestCheck.ps1'
$modes = if ($Mode -eq 'All') { @('Validate','Architecture','Specialized','Quality','HistoricalIntegrity') } else { @($Mode) }

foreach ($current in $modes) {
    switch ($current) {
        'Validate' {
            Invoke-Child 'profile-validate' $v3 @('-Mode','Validate','-ProfileDirectory',$profile,'-TargetRoot',$root,'-GenerationRoot',$packageRepository) @()
            Invoke-Child 'architecture-input-validate' $architecture @('-Mode','Validate','-TargetRoot',$root) @()
            Invoke-Child 'profile-views' $docs @('-Mode','Check','-ProfileDirectory',$profile,'-TargetRoot',$packageRepository) @()
            Invoke-Child 'ci-contract' $ciContract @('-TargetRoot',$root) @()
            Invoke-Child 'manifest-check' $manifestCheck @('-TargetRoot',$root) @()
        }
        'Pre' {
            $report = Join-Path $output 'pre.json'
            $args = @('-Mode','Pre','-ProfileDirectory',$profile,'-TargetRoot',$root,'-GenerationRoot',$packageRepository,'-ReportPath',(Relative $report))
            if ($PlanPath) { $args += @('-PlanPath',$PlanPath) } else { $args += @('-PlannedPaths') + $PlannedPaths }
            Invoke-Child 'pre' $v3 $args @((Relative $report))
        }
        'Diff' {
            $ownsGenerationRoot = -not $GenerationRoot
            $generation = [IO.Path]::GetFullPath($(if ($GenerationRoot) { $GenerationRoot } else {
                Join-Path ([IO.Path]::GetTempPath()) "guard-gen-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
            }))
            $generatedStages = Join-Path $generation 'v3-ifx/gates/stage/GuardV3.Tests'
            try {
                [void][IO.Directory]::CreateDirectory($generation)
                $common = @('-ProfileDirectory',$profile,'-TargetRoot',$root,'-GenerationRoot',$generation,'-OutputDirectory',$generatedStages,'-LockRoot',(Join-Path $packageRoot 'build/locks'),'-ProtectionPath',(Join-Path $packageRoot 'stages/diff/protection.json'))
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
foreach ($relative in @('profiles/ifx/profile.json','profiles/ifx/project-map.json','profiles/ifx/tech-stack.json','policy/authorities.json','policy/layerguard.json','history/manifest.json')) {
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
if (-not (Test-Json -LiteralPath $summaryPath -SchemaFile (Join-Path $packageRoot 'contracts/guard-summary.schema.json') -ErrorAction Stop)) { throw 'Unified summary does not match guard-summary.schema.json.' }
if ($summary.status -ne 'pass') { throw "IFX guardrails failed: $summaryPath" }
Write-Host "IFX guardrails passed: $summaryPath"
