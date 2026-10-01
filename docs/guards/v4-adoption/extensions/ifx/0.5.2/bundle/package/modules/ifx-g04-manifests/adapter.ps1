Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
$detector = 'ifx-g04-manifests'
$claims = @('IFX.C3.G04_INVENTORY','IFX.C3.G04_MANIFEST','IFX.C3.G04_ORCHESTRATION','IFX.C3.G04_FAILURE_POLICY')
$ruleIds = @('G04-INVENTORY','G04-MANIFEST','G04-ORCHESTRATION','G04-FAILURE-POLICY')
$kinds = @('runtime-inventory','release-manifest','release-policy','failure-policy')
$matched = @(0,0,0,0)
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i=0; $i -lt 4; $i++) { [ordered]@{ claimId=$claims[$i]; matched=[int]$matched[$i]; minimum=1 } }
    $result = [ordered]@{ formatVersion=1; status=$Status; exitCategory=$Category; findings=@($findings.ToArray()); coverage=@($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Check([int] $Index, [bool] $Condition, [string] $Subject) {
    if (-not $Condition) { $findings.Add([ordered]@{ ruleId=$ruleIds[$Index]; subject=$Subject; evidenceKind=$kinds[$Index]; detectorId=$detector; severity='blocking' }) }
}
function Same-Set($Actual, $Expected) {
    $left = @($Actual | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    $right = @($Expected | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    return ($left -join "`0") -ceq ($right -join "`0")
}
function Unique([object[]] $Values) { return @($Values | Sort-Object -Unique -CaseSensitive).Count -eq $Values.Count }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root,$Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path, [string] $Root) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while (Is-Under $cursor $Root) {
        if ([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' "Linked authority: $Path" }
        }
        if ($cursor -ceq $Root) { break }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }
}
function Read-Authority([string] $Root, [string] $Relative, [string] $ExpectedHash) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative -match '[*?]') { Stop-Adapter 'integrity-failure' "Unsafe authority path: $Relative" }
    $path = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $path $Root)) { Stop-Adapter 'integrity-failure' "Authority escapes TargetRoot: $Relative" }
    Assert-NoLink $path $Root
    if (-not [IO.File]::Exists($path)) { Stop-Adapter 'prerequisite-missing' "Missing authority: $Relative" }
    # 0.5.0-a: only governance authorities are pinned (ExpectedHash); live sources are read as they are.
    if ($ExpectedHash -and (Get-PinSha256 $path) -cne $ExpectedHash) { Stop-Adapter 'integrity-failure' "Stale governance authority: $Relative" }
    return [IO.File]::ReadAllText($path)
}
function Parse-Json([string] $Text, [string] $Label) {
    try { return ($Text | ConvertFrom-Json -AsHashtable -Depth 100) }
    catch { Stop-Adapter 'integrity-failure' "Malformed JSON: $Label" }
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
$inputObject = Parse-Json $env:V4_STAGE_INPUT_JSON 'Stage input'
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claims are invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
$policy = Parse-Json ([IO.File]::ReadAllText($policyPath)) 'candidate policy'
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g04-manifests-050a' -or $policy.pinPolicy -cne 'governance-only' -or
    (@($policy.claims) -join '|') -cne ($claims -join '|') -or @($policy.authorities).Count -ne 19) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$pinned = @($policy.authorities | Where-Object { $_.pinned -eq $true })
$authorityHashes = @($inputObject.config.authorityHashes)
if ($pinned.Count -ne 1 -or $authorityHashes.Count -ne $pinned.Count) { Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.' }
for ($n=0; $n -lt $pinned.Count; $n++) { if ($authorityHashes[$n].id -cne $pinned[$n].id -or [string]$authorityHashes[$n].sha256 -cnotmatch '^[a-f0-9]{64}$') { Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $n" } }
$texts = @{}
foreach ($authority in @($policy.authorities)) {
    $expected = if ($authority.pinned -eq $true) { [string](@($authorityHashes | Where-Object { $_.id -ceq $authority.id })[0].sha256) } else { '' }
    $texts[$authority.id] = Read-Authority $targetRoot ([string]$authority.path) $expected
}
try {
$json = @{}
foreach ($authority in @($policy.authorities | Where-Object { $_.path -like '*.json' })) { $json[$authority.id] = Parse-Json $texts[$authority.id] $authority.id }
$release = $json['runtime-release']; $modules = $json['module-manifest']; $units = $json['deployment-units']
$orchestration = $json['release-orchestration']; $evidence = $json['release-evidence-template']
$backpressure = $json['backpressure-policy']; $failure = $json['failure-matrix']; $dependency = $json['dependency-criticality']

# Phase-0 inventory is a frozen historical baseline; it is not a claim that the
# six recorded gaps remain current after the later G04 implementation phases.
$business = @([regex]::Matches($texts['source-program'],'Add(Crm|Holdings|Registry|Transaction)Module') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$matched[0] = $business.Count + @($policy.phase0KnownGaps).Count + 8
Check 0 (Same-Set $business $policy.phase0BusinessModules) 'business-modules'
Check 0 ($business.Count -eq 4) 'business-module-count'
Check 0 ($policy.phase0DeploymentUnits -eq 8) 'phase0-deployment-unit-count'
$businessAgain = @([regex]::Matches(([IO.File]::ReadAllText((Join-Path $targetRoot 'src/ApiHost/IFX.ApiHost/Program.cs'))),'Add(Crm|Holdings|Registry|Transaction)Module') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Check 0 (($businessAgain -join '|') -ceq ($business -join '|')) 'deterministic-inventory'
Check 0 ($texts['source-background-jobs'] -match 'AddHangfireServer') 'phase0-hangfire-coupling'
Check 0 ($texts['source-health'] -match '"/health/live"' -and $texts['source-health'] -match '"/health/startup"') 'live-startup-separation'
Check 0 ($texts['source-health'] -notmatch 'MapHealthChecks\("/health/live"[\s\S]*?Predicate = _ => true') 'live-ready-not-aggregate-equivalent'
Check 0 ($texts['compose'] -match 'sqlserver-init:[\s\S]*?ifx-database-migrator:[\s\S]*?sqlserver-init:' -and $texts['compose'] -match 'ifx-api:[\s\S]*?ifx-database-migrator:') 'phase0-compose-order'
Check 0 (@($policy.phase0KnownGaps).Count -ge 6 -and (Unique @($policy.phase0KnownGaps))) 'historical-known-gaps'
# 0.5.0-a: the 0.4.4 inventory-stability checks compared five live sources with their Profile pins only. They carried
# no content condition and are removed with the pins (check-changes.json); the content checks above remain.

$moduleIds = @($modules.modules | ForEach-Object { $_.moduleId })
$unitIds = @($units.units | ForEach-Object { $_.unitId })
$matched[1] = $moduleIds.Count + $unitIds.Count + @($release.bindings.Keys).Count
Check 1 ($moduleIds.Count -gt 0 -and (Same-Set $moduleIds $policy.moduleIds) -and (Unique $moduleIds)) 'module-set'
Check 1 (@($modules.modules | Where-Object { $_.required -ne $true }).Count -eq 0) 'required-modules'
$endpointIds = @($modules.modules | ForEach-Object { @($_.endpointGroups) })
Check 1 ($endpointIds.Count -gt 0 -and (Unique $endpointIds)) 'endpoint-identity'
Check 1 ($unitIds.Count -gt 0 -and (Same-Set $unitIds $policy.deploymentUnitIds) -and (Unique $unitIds)) 'deployment-unit-set'
$apiWorker = @($units.units | Where-Object { $_.unitId -in @('ifx-api','ifx-worker') })
Check 1 ($apiWorker.Count -eq 2 -and $apiWorker[0].artifact -ceq $apiWorker[1].artifact -and $apiWorker[0].artifact -ceq $release.hostArtifact.artifactId) 'api-worker-artifact'
Check 1 (Same-Set $release.requiredModuleIds $moduleIds) 'release-required-modules'
Check 1 ($release.schemaCompatibility.policy -ceq 'expand-contract' -and $release.schemaCompatibility.cleanupRequires -ceq 'observed-zero-old-version-demand') 'schema-compatibility'
Check 1 ($release.businessBoundary -ceq 'ifx-backend' -and [string]$release.hostArtifact.digest -match '^sha256:[a-f0-9]{64}$') 'release-artifact'
# A checked-in release digest identifies a frozen artifact, not necessarily the
# current csproj. V3 regenerates a candidate descriptor but does not equate it
# to this checked-in release. Preserve that boundary until C3e comparison.
Check 1 ($release.releaseId -ceq $modules.releaseVersion -and
    (@($release.hostArtifact.allowedRoles) -join '|') -ceq 'api|worker|all') 'release-module-identity'
Check 1 (-not [string]::IsNullOrWhiteSpace($texts['g04-adr'])) 'g04-adr'
Check 1 ($release.bindings.Count -eq 8 -and (Same-Set @($release.bindings.Keys) $policy.releaseBindingKeys)) 'binding-key-set'
$bindingPaths = @{
    moduleManifest='deployment/g04/module-manifest.json'; deploymentUnitCatalog='deployment/g04/deployment-unit-catalog.json'
    infrastructureCompatibility='deployment/g04/infrastructure-compatibility-matrix.json'; schemaReleaseManifest='deployment/release-manifest.json'
    migrationManifest='src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'; releaseOrchestration='deployment/g04/release-orchestration.json'
    backpressurePolicy='deployment/g04/backpressure-policy.json'; failureMatrix='deployment/g04/failure-matrix.json'
}
foreach ($key in @($policy.releaseBindingKeys)) {
    $binding = $release.bindings[$key]
    $entry = @($policy.authorities | Where-Object { $_.path -ceq $bindingPaths[$key] })
    # 0.5.0-a: a release binding must name the current bytes of the bound file (0.4.4 compared it with the Profile pin).
    $bound = Join-Path $targetRoot $bindingPaths[$key]
    $actual = if ($entry.Count -eq 1 -and [IO.File]::Exists($bound)) { (Get-FileHash -Algorithm SHA256 -LiteralPath $bound).Hash.ToLowerInvariant() } else { $null }
    Check 1 ($entry.Count -eq 1 -and $null -ne $actual -and $null -ne $binding -and $binding.path -ceq $bindingPaths[$key] -and $binding.sha256 -ceq $actual) "binding:$key"
}
Check 1 (@($json['infrastructure-compatibility'].dependencies | Where-Object { -not $_.owner -or -not $_.upgradeResponsibility }).Count -eq 0) 'infrastructure-owners'
$dependencyIds = @($dependency.dependencies | ForEach-Object { $_.dependencyId })
Check 1 ($dependencyIds.Count -gt 0 -and (Unique $dependencyIds)) 'dependency-identity'
Check 1 (@($dependency.dependencies | Where-Object { $_.criticality -notin @('startup-fatal','readiness-critical','capability-critical','optional','operational') }).Count -eq 0) 'dependency-criticality'
$requiredDimensions = @('moduleId','eventCategory','pendingCount','oldestPendingAge','retryCount','deadLetterCount','lastSucceeded','processingRatePerSecond','storageUtilization','expiredLeaseCount','duplicateRate','consecutiveFailures','dispatcherSilence')
Check 1 (Same-Set $backpressure.requiredDimensions $requiredDimensions) 'backpressure-dimensions'
try {
    $t = $backpressure.thresholds
    $ordered = ([TimeSpan]::Parse($t.warningAge) -lt [TimeSpan]::Parse($t.criticalAge)) -and
        ($t.warningCount -lt $t.criticalCount) -and ($t.warningConsecutiveFailures -lt $t.criticalConsecutiveFailures) -and
        ([TimeSpan]::Parse($t.warningSilence) -lt [TimeSpan]::Parse($t.criticalSilence))
    Check 1 $ordered 'backpressure-threshold-order'
} catch { Check 1 $false 'backpressure-threshold-format' }
try { Check 1 (Test-Json -Json $texts['module-manifest'] -SchemaFile (Join-Path $targetRoot 'deployment/g04/module-manifest.schema.json') -ErrorAction Stop) 'module-schema' }
catch { Check 1 $false 'module-schema' }

$stageIds = @($orchestration.stages | ForEach-Object { $_.stageId })
$matched[2] = $stageIds.Count
Check 2 ($stageIds.Count -gt 0 -and (Same-Set $stageIds $policy.releaseStageIds) -and (Unique $stageIds) -and ($stageIds -join '|') -ceq (@($policy.releaseStageIds) -join '|')) 'release-stage-order'
$index = @{}; for ($n=0; $n -lt $stageIds.Count; $n++) { $index[$stageIds[$n]] = $n }
foreach ($stage in @($orchestration.stages)) {
    foreach ($required in @($stage.requires)) { Check 2 ($index.ContainsKey([string]$required) -and $index[[string]$required] -lt $index[[string]$stage.stageId]) "stage-dependency:$($stage.stageId)" }
}
Check 2 ((@($evidence.stages | ForEach-Object { $_.stageId }) -join '|') -ceq ($stageIds -join '|')) 'release-evidence-template'
Check 2 ($orchestration.releaseStrategy -ceq 'consumer-first-expand-contract' -and $orchestration.failureDefault -ceq 'stop-and-preserve-compatible-release') 'release-strategy'
Check 2 (($orchestration.stages | Where-Object stageId -eq 'database-migrator').failureAction -ceq 'stop-no-down') 'migrator-no-down'
Check 2 ($index.ContainsKey('worker-consumer') -and $index.ContainsKey('api-producer') -and $index['worker-consumer'] -lt $index['api-producer']) 'worker-before-api'
Check 2 ('observation' -in @(($orchestration.stages | Where-Object stageId -eq 'contract-cleanup').requires)) 'cleanup-observation'
Check 2 (@($orchestration.dataJobs).Count -eq 4 -and @($orchestration.dataJobs | Where-Object { -not $_.owner -or $_.idempotencyRequired -ne $true -or $_.automatic -ne $false }).Count -eq 0) 'data-job-ownership'
Check 2 ($evidence.status -cne 'completed') 'structure-only-not-production'

$scenarios = @($failure.scenarios)
$scenarioIds = @($scenarios | ForEach-Object { $_.scenarioId })
$matched[3] = $scenarioIds.Count
Check 3 ($scenarioIds.Count -gt 0 -and (Same-Set $scenarioIds $policy.failureScenarioIds) -and (Unique $scenarioIds)) 'failure-scenario-set'
Check 3 (@($scenarios | Where-Object { -not $_.module -or -not $_.dependency -or -not $_.role -or -not $_.reason -or -not $_.action -or -not $_.recovery }).Count -eq 0) 'failure-dimensions'
Check 3 (@($scenarios | Where-Object { 'automatic-down' -in @($_.prohibitions) }).Count -ge 2) 'automatic-down-prohibited'
$transport = $scenarios | Where-Object scenarioId -eq 'transport-or-storage-outage' | Select-Object -First 1
if ($null -eq $transport) { Check 3 $false 'transport-preserves-truth' }
else { Check 3 ('delete-outbox' -in @($transport.prohibitions) -and 'invent-delivered' -in @($transport.prohibitions)) 'transport-preserves-truth' }
$v2 = $scenarios | Where-Object scenarioId -eq 'api-v2-produced-before-rollback' | Select-Object -First 1
if ($null -eq $v2) { Check 3 $false 'v2-worker-retention' }
else { Check 3 ('remove-v2-consumer' -in @($v2.prohibitions) -and $v2.action -ceq 'retain-v2-worker-while-api-rolls-back') 'v2-worker-retention' }
$shutdown = $scenarios | Where-Object scenarioId -eq 'shutdown-timeout' | Select-Object -First 1
Check 3 ($null -ne $shutdown -and $shutdown.action -ceq 'force-exit-after-grace') 'bounded-shutdown'

if (@($findings).Count -gt 0) { Emit 'fail' 'findings-blocking' }
else { Emit 'pass' 'success' }
} catch { Stop-Adapter 'integrity-failure' "Invalid G04 authority structure: $($_.Exception.Message)" }
