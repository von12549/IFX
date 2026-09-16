[CmdletBinding()]
param(
    [string] $PolicyPath = 'docs/architecture/review/policies/plan04/cross-module-projection-policy.json',
    [string] $SchemaPath = 'docs/architecture/review/policies/plan04/projection-registration.schema.json',
    [string] $RegistryPath = 'docs/architecture/review/policies/plan04/projection-registry.json',
    [string] $CatalogPath = 'docs/architecture/review/gates/G03/contract-event-catalog.yaml',
    [string] $GraphPath = 'docs/architecture/review/evidence/plan04/module-boundary-dependency-graph.json',
    [string] $InventoryPath = 'docs/architecture/review/evidence/plan04/cross-module-query-inventory.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase5-projection-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path }; Join-Path $repositoryRoot $path }
function Sha256([string] $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant() }
function HasText([object] $value) { -not [string]::IsNullOrWhiteSpace([string]$value) }
function ReadJson([string] $path) { Get-Content -Raw -LiteralPath (Repo $path) | ConvertFrom-Json -Depth 100 }

function Test-Registration([object] $registration, [bool] $requireRegistry = $true) {
    $errors = [Collections.Generic.List[string]]::new()
    $raw = $registration | ConvertTo-Json -Depth 100 -Compress
    $dbContexts = @([regex]::Matches($raw, '\b[A-Za-z]+DbContext\b') | ForEach-Object Value | Sort-Object -Unique)
    if ($dbContexts.Count -gt 1 -or $raw -match 'cross-module-table-join') { $errors.Add('cross-dbcontext-or-table-join') }
    if ($registration.status -eq 'approved' -and ($registration.registrationPresent -eq $false -or -not $requireRegistry)) { $errors.Add('unregistered-projection') }
    if ($registration.status -eq 'approved') {
        if (-not (HasText $registration.semantics.inbox) -or -not (HasText $registration.semantics.idempotencyKey)) { $errors.Add('duplicate-business-effect-risk') }
        if (-not (HasText $registration.lifecycle.rebuild) -or -not (HasText $registration.lifecycle.reconciliation) -or -not (HasText $registration.lifecycle.driftDetection)) { $errors.Add('rebuild-drift-risk') }
        if ($registration.privacy.sourceFieldSuperset -eq $true) { $errors.Add('sensitive-field-superset') }
    }
    @($errors | Sort-Object -Unique)
}

$policy = ReadJson $PolicyPath
$schema = ReadJson $SchemaPath
$registry = ReadJson $RegistryPath
$catalog = ReadJson $CatalogPath
$graph = ReadJson $GraphPath
$baseline = ReadJson 'docs/architecture/review/evidence/plan04/phase0-baseline-inputs.json'
$approved = @($registry.approvedCrossModuleQueryConsumers)
$publicSchemas = @($registry.publicProjectionSchemas)
$references = @($registry.references)
$holdingsReference = @($references | Where-Object id -eq 'holdings-event-consumer')
$schemaValidationResults = @()
foreach ($reference in $references) {
    $schemaValidationResults += [ordered]@{ id = $reference.id; valid = Test-Json -Json ($reference | ConvertTo-Json -Depth 100) -SchemaFile (Repo $SchemaPath) -ErrorAction SilentlyContinue }
}
$activeProtocolIds = @($catalog.protocols | Where-Object lifecycle -eq 'Active' | ForEach-Object identity)
$referenceProtocolResults = @()
foreach ($protocol in @($holdingsReference.sourceProtocols)) {
    $referenceProtocolResults += [ordered]@{ identity = $protocol; activeInG03 = $protocol -in $activeProtocolIds }
}

$holdingHandlerPath = Repo 'src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Integrations/Inbound/HoldingsInboundIntegrationEventHandler.cs'
$holdingInboxPath = Repo 'src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Messaging/HoldingsInboxConfiguration.cs'
$transactionHandlerPath = Repo 'src/Modules/Holdings/IFX.Modules.Holdings.Application/Integrations/ApplyTransactionProcessedCommand.cs'
$classHandlerPath = Repo 'src/Modules/Holdings/IFX.Modules.Holdings.Application/Integrations/ApplyClassStatusChangedCommand.cs'
$holdingHandler = Get-Content -Raw -LiteralPath $holdingHandlerPath
$holdingInbox = Get-Content -Raw -LiteralPath $holdingInboxPath
$transactionHandler = Get-Content -Raw -LiteralPath $transactionHandlerPath
$classHandler = Get-Content -Raw -LiteralPath $classHandlerPath
$referenceImplementation = [ordered]@{
    tenantEnvelopeValidated = $holdingHandler -match 'TenantId is null|TenantId == Guid.Empty'
    inboxUniqueConsumerEvent = $holdingInbox -match 'ConsumerId, message.EventId' -and $holdingInbox -match 'IsUnique'
    transactionConsumerChecksInbox = $transactionHandler -match 'HasCompletedAsync\(request.ConsumerId, request.Metadata.EventId'
    classConsumerChecksInbox = $classHandler -match 'HasCompletedAsync\(request.ConsumerId, request.Metadata.EventId'
}

$forbiddenPhysicalEdges = @($graph.physicalCrossModuleEdges | Where-Object {
    $_.classification -ne 'registered-cross-module-protocol' -or $_.toRole -notin @('Contracts', 'Events')
})
$sourceFiles = @(Get-ChildItem -LiteralPath (Repo 'src/Modules') -Recurse -File -Filter '*.cs')
$crossDbContextFiles = @()
foreach ($file in $sourceFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $contexts = @([regex]::Matches($text, '\b(?:Auth|CRM|Registry|Transaction|Holdings)DbContext\b') | ForEach-Object Value | Sort-Object -Unique)
    if ($contexts.Count -gt 1) { $crossDbContextFiles += [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/') }
}

$fixtureExpectations = [ordered]@{
    'projection-positive-approved.json' = @()
    'projection-negative-cross-dbcontext.json' = @('cross-dbcontext-or-table-join','duplicate-business-effect-risk','rebuild-drift-risk')
    'projection-negative-unregistered.json' = @('duplicate-business-effect-risk','rebuild-drift-risk','unregistered-projection')
    'projection-negative-duplicate-effect.json' = @('duplicate-business-effect-risk','rebuild-drift-risk')
    'projection-negative-rebuild-drift.json' = @('duplicate-business-effect-risk','rebuild-drift-risk')
    'projection-negative-sensitive-superset.json' = @('duplicate-business-effect-risk','rebuild-drift-risk','sensitive-field-superset')
}
$fixtureResults = @()
foreach ($fixture in $fixtureExpectations.Keys) {
    $document = ReadJson "tests/Architecture/Plan04/Fixtures/$fixture"
    $actual = @(Test-Registration $document ($document.registrationPresent -ne $false))
    $expected = @($fixtureExpectations[$fixture] | Sort-Object)
    $fixtureResults += [ordered]@{ fixture = $fixture; expectedErrors = $expected; actualErrors = $actual; passed = ($expected -join '|') -eq ($actual -join '|') }
}

$checks = [ordered]@{
    noProjectionWithoutApprovedConsumer = $policy.defaultDecision -eq 'no-projection-without-approved-consumer'
    allowedPathsAreClosedSet = @($policy.allowedReadPaths).Count -eq 2 -and 'local-versioned-contract' -in $policy.allowedReadPaths -and 'registered-owned-projection' -in $policy.allowedReadPaths
    crossDatabaseReadsForbidden = 'cross-dbcontext-join' -in $policy.forbiddenReadPaths -and 'cross-module-table-join' -in $policy.forbiddenReadPaths
    registrationSchemaRequiresLifecyclePrivacyAndApprovals = @('lifecycle','failureRecovery','privacy','approvals') | ForEach-Object { $_ -in $schema.required } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { $_ -eq 0 }
    approvedConsumerInventoryIsExplicitlyEmpty = $approved.Count -eq 0 -and $publicSchemas.Count -eq 0
    holdingsIsReferenceOnly = $holdingsReference.Count -eq 1 -and $holdingsReference.status -eq 'reference-only'
    registryEntriesConformToSchema = @($schemaValidationResults | Where-Object valid -ne $true).Count -eq 0
    referenceProtocolsAreActiveInG03 = $referenceProtocolResults.Count -eq 2 -and @($referenceProtocolResults | Where-Object activeInG03 -ne $true).Count -eq 0
    holdingsReferenceHasTenantInboxAndIdempotency = @($referenceImplementation.GetEnumerator() | Where-Object Value -ne $true).Count -eq 0
    noForbiddenPhysicalModuleEdges = $forbiddenPhysicalEdges.Count -eq 0
    noSourceFileUsesMultipleModuleDbContexts = $crossDbContextFiles.Count -eq 0
    negativeFixturesPass = @($fixtureResults | Where-Object passed -ne $true).Count -eq 0
    privacyAndRollbackAreFailClosed = $policy.privacy.supersetOfSourceAllowed -eq $false -and $policy.privacy.deletionBypassAllowed -eq $false -and $policy.rollout -match 'Never fall back'
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$inventory = [ordered]@{
    formatVersion = 1; plan = '04-module-boundary-evolution'; slice = 'P04-S5'; asOf = $baseline.capturedAt
    approvedCrossModuleQueryConsumerCount = $approved.Count; publicProjectionSchemaCount = $publicSchemas.Count
    references = $references; schemaValidationResults = $schemaValidationResults; referenceProtocolResults = $referenceProtocolResults; referenceImplementation = $referenceImplementation
    physicalCrossModuleEdges = @($graph.physicalCrossModuleEdges); forbiddenPhysicalEdges = $forbiddenPhysicalEdges
    crossDbContextFiles = $crossDbContextFiles
    conclusion = 'No approved reporting/query consumer exists; no public projection schema is authorized. Holdings is reference-only.'
}
$inventory | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Repo $InventoryPath) -Encoding utf8NoBOM
$status = [ordered]@{
    formatVersion = 1; plan = '04-module-boundary-evolution'; slice = 'P04-S5'
    result = if ($failed.Count -eq 0) { 'repository-passed-no-reporting-product-claimed' } else { 'failed' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd'); policySha256 = Sha256 $PolicyPath; schemaSha256 = Sha256 $SchemaPath; registrySha256 = Sha256 $RegistryPath
    inventorySha256 = Sha256 $InventoryPath; catalogSha256 = Sha256 $CatalogPath; dependencyGraphSha256 = Sha256 $GraphPath
    checks = $checks; fixtureResults = $fixtureResults
    metrics = [ordered]@{ approvedConsumers = $approved.Count; publicSchemas = $publicSchemas.Count; referenceImplementations = $references.Count; forbiddenEdges = $forbiddenPhysicalEdges.Count; crossDbContextFiles = $crossDbContextFiles.Count }
    productionReportingValidation = 'not-run-not-claimed'; approvals = 'pending-for-any-future-consumer'; failedChecks = $failed
}
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Repo $StatusPath) -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 04 projection validation failed: $($failed -join ', '). Report: $(Repo $StatusPath)" }
Write-Host "Plan 04 projection result: $($status.result). Report: $(Repo $StatusPath)"
