[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [Parameter(Mandatory)][string] $HeadRevision,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/trusted-base/policy-candidates.json',
    [string] $WorkRoot
)

# Plan 06 §12.4 track two (CP06b1, D24): the base engine validates the head candidates of registered policy and
# configuration files, read as Git objects of the explicit head commit, without letting them decide the current verdict.
#  - json and json-schema entries parse, and validate against their registered schema (the head schema when this pull
#    request changes that schema);
#  - v3-profile entries: the base V3 runner validates the head profile, and the base renderer checks its views, in a
#    detached worktree of the head commit;
#  - history-manifest: the base historical integrity engine checks the head manifest against head evidence (references,
#    hashes and summaries);
#  - derived projections equal what the base generator produces from head authority sources, using only the exact targets
#    of the base authority registry;
#  - the head registry is schema-valid and declares monotonicity for every field of every schema it registers.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packagePath = 'docs/guards/V3_ifx'
$baseRepository = Get-GuardFullPath (Join-Path $packageRoot '../../..')
$target = Get-GuardFullPath $TargetRoot
$report = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $target $ReportPath }))
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$work = if ($WorkRoot) { Get-GuardFullPath $WorkRoot } else { Get-GuardFullPath (Join-Path $tempRoot "guard-policy-$([Guid]::NewGuid().ToString('N').Substring(0, 8))") }
$failures = [Collections.Generic.List[string]]::new()
$validated = [Collections.Generic.List[object]]::new()
$headTreeAdded = $false
$result = [ordered]@{ formatVersion = 1; check = 'policy-candidates'; status = 'fail'; baseSha = $BaseSha; mergeBase = $null; headSha = $null; policyRegistrySha256 = $null; validations = @(); failures = @() }

function Add-Validation([string] $Kind, [string] $Subject, [string[]] $Problems) {
    $list = @($Problems | Where-Object { $_ })
    $validated.Add([ordered]@{ kind = $Kind; subject = $Subject; status = if ($list.Count -eq 0) { 'pass' } else { 'fail' } })
    foreach ($problem in $list) { $failures.Add("${Kind} ${Subject}: $problem") }
}
function Write-HeadBlob([string] $Commit, [string] $Path, [string] $Destination) {
    $bytes = Get-GuardBlobBytes $target $Commit $Path
    if ($null -eq $bytes) { return $false }
    if (-not (Test-GuardPathWithin $Destination $work)) { throw "Unsafe materialization path: $Path" }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination))
    [IO.File]::WriteAllBytes($Destination, $bytes)
    return $true
}
function Get-RunTail([object] $Run) { return (($Run.Output -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 6) -join ' | ') }

try {
    $packageHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD'))
    if ($packageHead.Count -ne 1 -or $packageHead[0] -ne $BaseSha) { throw "The validator must run from the base commit $BaseSha, not $($packageHead -join '')." }
    if ((Resolve-GuardCommit $target $BaseSha) -ne $BaseSha) { throw "Target repository does not contain base commit $BaseSha." }
    $headSha = Resolve-GuardCommit $target $HeadRevision
    $result.headSha = $headSha
    $mergeBase = @(Invoke-GuardGit $target @('merge-base', $BaseSha, $headSha) -AllowFailure)
    if ($LASTEXITCODE -ne 0 -or $mergeBase.Count -ne 1) { throw 'Base and head have no single merge base; fetch complete history.' }
    $mergeBase = $mergeBase[0]
    $result.mergeBase = $mergeBase
    if ((Test-GuardPathWithin $work $target) -or (Test-GuardPathWithin $work $baseRepository)) { throw 'WorkRoot must be outside the target and the base worktree.' }
    [void][IO.Directory]::CreateDirectory($work)

    $registry = Read-GuardPolicyRegistry $packageRoot
    $result.policyRegistrySha256 = $registry.sha256
    $baseAuthorityRegistryFile = Resolve-GuardAuthorityRegistryPath $packageRoot
    $authorities = Get-Content -LiteralPath $baseAuthorityRegistryFile -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $projectionTargets = Get-GuardProjectionTargets $authorities $packagePath
    $authorityRegistryPath = Get-GuardAuthorityRegistryPathAtCommit $target $headSha $packagePath
    $headAuthoritiesText = Get-GuardBlobText $target $headSha $authorityRegistryPath
    if ($null -eq $headAuthoritiesText) { throw "Head removes the authority registry: $authorityRegistryPath" }
    $headAuthorities = ConvertFrom-GuardJsonText $headAuthoritiesText
    $headProjectionTargets = Get-GuardProjectionTargets $headAuthorities $packagePath
    $registryPath = "$packagePath/shared/policy-config.json"
    $headRegistryText = Get-GuardBlobText $target $headSha $registryPath
    if ($null -eq $headRegistryText -or -not (Test-GuardJsonSchema -Schema (Resolve-GuardContractPath $packageRoot 'policy-config') -Json $headRegistryText)) { throw 'The head policy registry is missing or invalid under the base schema.' }
    $headRegistry = ConvertFrom-GuardJsonText $headRegistryText
    $entries = @(Get-GuardChangedEntries $target $mergeBase $headSha)
    $changedPaths = [Collections.Generic.HashSet[string]]::new([string[]]@($entries | ForEach-Object { $_.Path }), [StringComparer]::Ordinal)
    $policy = Get-GuardPolicyChanges $target $mergeBase $headSha $registry $projectionTargets $entries -HeadRegistry $headRegistry -HeadProjectionTargets $headProjectionTargets

    # ---- per-file candidates
    $profileChanged = $false
    $historyChanged = $false
    foreach ($change in @($policy.Changes | Where-Object { $null -ne $_.Head })) {
        $text = Get-GuardBlobText $target $headSha $change.Path
        $problems = [Collections.Generic.List[string]]::new()
        switch ($change.Entry.candidateValidation) {
            'normalized-text' { }
            'v3-profile' { $profileChanged = $true }
            'history-manifest' { $historyChanged = $true }
            default {
                try { [void](ConvertFrom-GuardJsonText $text) } catch { $problems.Add("is not valid JSON: $($_.Exception.Message)") }
                if ($problems.Count -eq 0 -and $change.Entry.ContainsKey('schema')) {
                    $schemaPath = [string]$change.Entry.schema
                    $schemaFile = Join-Path $baseRepository $schemaPath
                    if ($changedPaths.Contains($schemaPath)) {
                        $schemaFile = Join-Path $work "schemas/$([IO.Path]::GetFileName($schemaPath))"
                        if (-not (Write-HeadBlob $headSha $schemaPath $schemaFile)) { $problems.Add("its schema $schemaPath is removed in head") }
                    }
                    if ($problems.Count -eq 0 -and -not (Test-GuardJsonSchema -Schema $schemaFile -Json $text)) { $problems.Add("does not match $schemaPath") }
                }
            }
        }
        Add-Validation $change.Entry.candidateValidation $change.Path ([string[]]@($problems))
    }

    if ($profileChanged) {
        # Project map paths are checked against the tree, so the base runner validates a worktree of the explicit head commit.
        $headTree = Join-Path $work 'head-tree'
        [void](Invoke-GuardGit $target @('worktree', 'add', '--detach', '--quiet', $headTree, $headSha))
        $headTreeAdded = $true
        $profileGeneration = Join-Path $work 'profile-generation'
        [void][IO.Directory]::CreateDirectory($profileGeneration)
        $layoutPath = Join-Path $headTree "$packagePath/shared/profile-layout.json"
        $run = Invoke-GuardIsolatedPwsh (Join-Path $baseRepository 'docs/guards/V3/commands/Invoke-V3.ps1') @('-Mode', 'Validate', '-ProfileLayoutPath', $layoutPath, '-TargetRoot', $headTree, '-GenerationRoot', $profileGeneration) -WorkingDirectory $work
        Add-Validation 'v3-profile' "$packagePath/shared/profile-layout.json" $(if ($run.ExitCode -eq 0) { @() } else { @("the base V3 runner rejects the head profile: $(Get-RunTail $run)") })
        # The generated profile views are checked after merge, so a head profile with stale views would break the next base.
        $views = Invoke-GuardIsolatedPwsh (Join-Path $baseRepository 'docs/guards/V3/commands/Invoke-V3Docs.ps1') @('-Mode', 'Check', '-ProfileLayoutPath', $layoutPath, '-TargetRoot', $headTree, '-PackageDirectory', (Join-Path $headTree $packagePath)) -WorkingDirectory $work
        Add-Validation 'v3-profile-views' "$packagePath/profiles/ifx/views/" $(if ($views.ExitCode -eq 0) { @() } else { @("the head profile views differ from what the base renderer produces: $(Get-RunTail $views)") })
    }

    if ($historyChanged) {
        $historyRoot = Join-Path $work 'history'
        $legacyManifestPath = "$packagePath/history/manifest.json"
        $stageManifestPath = "$packagePath/stages/post/gates/historical-integrity/manifest.json"
        $legacyManifest = $null -ne (Get-GuardTreeEntry $target $headSha $legacyManifestPath)
        $stageManifest = $null -ne (Get-GuardTreeEntry $target $headSha $stageManifestPath)
        if ($legacyManifest -eq $stageManifest) { throw 'Head must contain exactly one legacy or stage-owned Historical Integrity manifest.' }
        $manifestPath = if ($stageManifest) { $stageManifestPath } else { $legacyManifestPath }
        [void](Write-HeadBlob $headSha $manifestPath (Join-Path $historyRoot $manifestPath))
        $manifest = ConvertFrom-GuardJsonText (Get-GuardBlobText $target $headSha $manifestPath)
        $referenced = @(@($manifest.entries) | ForEach-Object { [string]$_.path }) + @(@($manifest.references) | ForEach-Object { [string]$_.source; [string]$_.target })
        foreach ($path in @($referenced | Where-Object { $_ } | Sort-Object -Unique)) {
            if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|[\\/])\.\.([\\/]|$)') { continue }
            [void](Write-HeadBlob $headSha $path.Replace('\', '/') (Join-Path $historyRoot $path))
        }
        $legacyEnginePath = Join-Path $packageRoot 'history/Invoke-IFXHistoricalIntegrity.ps1'
        $stageEnginePath = Join-Path $packageRoot 'stages/post/gates/historical-integrity/Invoke-IFXHistoricalIntegrity.ps1'
        if ([IO.File]::Exists($legacyEnginePath) -eq [IO.File]::Exists($stageEnginePath)) { throw 'Base package must contain exactly one legacy or stage-owned Historical Integrity engine.' }
        $historyEngine = if ([IO.File]::Exists($stageEnginePath)) { $stageEnginePath } else { $legacyEnginePath }
        $run = Invoke-GuardIsolatedPwsh $historyEngine @('-RepositoryRoot', $historyRoot, '-ManifestPath', $manifestPath, '-ReportPath', (Join-Path $historyRoot 'history-summary.json')) -WorkingDirectory $work
        Add-Validation 'history-manifest' $manifestPath $(if ($run.ExitCode -eq 0) { @() } else { @("the base historical integrity engine rejects the head manifest against head evidence: $(Get-RunTail $run)") })
    }

    # ---- derived projections: only the exact targets of the base authority registry, regenerated by the base generator
    $sources = @(@(@($authorities.projections) + @($authorities.g04Bindings) + @($headAuthorities.projections) + @($headAuthorities.g04Bindings) | ForEach-Object { [string]$_.source }) | Sort-Object -Unique)
    $projectionTouched = @($entries | Where-Object { $projectionTargets.Contains($_.Path) -or $headProjectionTargets.Contains($_.Path) -or $sources -ccontains $_.Path }).Count -gt 0
    if ($projectionTouched) {
        $package = Join-Path $work "projection/package/$packagePath"
        $sourceRoot = Join-Path $work 'projection/sources'
        [void][IO.Directory]::CreateDirectory($package)
        [void](Write-HeadBlob $headSha $authorityRegistryPath (Join-Path $work "projection/package/$authorityRegistryPath"))
        $legacyMarker = "$packagePath/policy/layerguard.json"
        $stageMarker = "$packagePath/stages/post/policy/layerguard.json"
        $legacyLayout = $null -ne (Get-GuardTreeEntry $target $headSha $legacyMarker)
        $stageLayout = $null -ne (Get-GuardTreeEntry $target $headSha $stageMarker)
        if ($legacyLayout -eq $stageLayout) { throw 'Head must contain exactly one complete legacy or stage-owned policy layout.' }
        $policyMarker = if ($stageLayout) { $stageMarker } else { $legacyMarker }
        [void](Write-HeadBlob $headSha $policyMarker (Join-Path $work "projection/package/$policyMarker"))
        foreach ($projectionTarget in $headProjectionTargets) { [void](Write-HeadBlob $headSha $projectionTarget (Join-Path $work "projection/package/$projectionTarget")) }
        foreach ($source in @($sources | Sort-Object -Unique)) { [void](Write-HeadBlob $headSha $source (Join-Path $sourceRoot $source)) }
        $run = Invoke-GuardIsolatedPwsh (Join-Path $packageRoot 'maintenance/Sync-IFXPolicyInputs.ps1') @('-Mode', 'Check', '-PackageRoot', $package, '-TargetRoot', $sourceRoot) -WorkingDirectory $work
        Add-Validation 'derived-projection' ([IO.Path]::GetDirectoryName($policyMarker).Replace('\', '/') + '/') $(if ($run.ExitCode -eq 0) { @() } else { @("head projections differ from the base generator output for head authorities: $(Get-RunTail $run)") })
    }

    # ---- head registry: schema-valid, and a monotonicity declaration for every field of every registered schema
    $registeredSchemas = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in @(@($registry.entries) + @($headRegistry.entries))) { if ($entry.ContainsKey('schema')) { [void]$registeredSchemas.Add([string]$entry.schema) } }
    $registryTouched = $changedPaths.Contains($registryPath) -or @($entries | Where-Object { $registeredSchemas.Contains($_.Path) -or $_.Path.EndsWith('.schema.json', [StringComparison]::Ordinal) }).Count -gt 0
    if ($registryTouched) {
        $problems = [Collections.Generic.List[string]]::new()
        if ($null -eq $headRegistryText) { $problems.Add('head removes the policy and configuration registry') }
        else {
            $registrySchema = Resolve-GuardContractPath $packageRoot 'policy-config'
            $headRegistrySchemaPath = Get-GuardContractPathAtCommit $target $headSha 'policy-config' $packagePath
            if ($changedPaths.Contains($headRegistrySchemaPath) -or @($entries | Where-Object { $_.Path.EndsWith('/policy-config.schema.json', [StringComparison]::Ordinal) }).Count -gt 0) {
                $registrySchema = Join-Path $work 'schemas/policy-config.schema.json'
                if (-not (Write-HeadBlob $headSha $headRegistrySchemaPath $registrySchema)) { $problems.Add("head removes the policy-config schema: $headRegistrySchemaPath") }
            }
            if ($problems.Count -eq 0 -and -not (Test-GuardJsonSchema -Schema $registrySchema -Json $headRegistryText)) { $problems.Add('does not match the policy-config schema') }
            else {
                $headRegistry = ConvertFrom-GuardJsonText $headRegistryText
                $read = { param($schema) Get-GuardBlobText $target $headSha $schema }
                foreach ($problem in (Test-GuardMonotonicityDeclarations $headRegistry $read)) { $problems.Add($problem) }
            }
        }
        Add-Validation 'policy-registry' $registryPath ([string[]]@($problems))
    }
}
catch {
    $failures.Add($_.Exception.Message)
}
finally {
    if ($headTreeAdded) { [void](Invoke-GuardGit $target @('worktree', 'remove', '--force', (Join-Path $work 'head-tree')) -AllowFailure); [void](Invoke-GuardGit $target @('worktree', 'prune') -AllowFailure) }
    if (-not $WorkRoot -and [IO.Directory]::Exists($work)) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

$result.validations = @($validated)
$result.failures = @($failures)
if ($failures.Count -eq 0) { $result.status = 'pass' }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
[IO.File]::WriteAllText($report, ($result | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    Write-Host "Policy candidate validation failed: $report"
    exit 1
}
Write-Host "Policy candidate validation passed ($($validated.Count) validation(s)): $report"
