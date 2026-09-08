[CmdletBinding()]
param(
    [ValidateRange(0, 11)]
    [int]$Phase = 0,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "docs/architecture/review/evidence/gates/G05/G05-phase$Phase-guard-report.json"
}
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$inventoryPath = Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-context-inventory.json'

if ($Phase -eq 0) {
    & (Join-Path $PSScriptRoot 'Invoke-G05ContextInventory.ps1') -ReportPath $inventoryPath
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    & (Join-Path $PSScriptRoot 'Invoke-G05ContextInventory.ps1') -ReportPath $inventoryPath
    $secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
} else {
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    $secondHash = $firstHash
}
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 50

$checks = [ordered]@{
    deterministicInventory = $firstHash -eq $secondHash
    valueFreeInventoryPolicy = $inventory.inventoryPolicy -eq 'source-locations-and-schema-names-only-no-runtime-values'
    sourceInventoryNonEmpty = $inventory.source.csFiles -gt 100
    httpAndTenantSurfacesRecorded = @($inventory.surfaces.httpHeaders).Count -gt 0 -and @($inventory.surfaces.claimsAndCurrentUser).Count -gt 0
    protocolAndEventSurfacesRecorded = $inventory.source.publicProtocolFiles -gt 0 -and $inventory.source.eventFiles -gt 0
    loggingAndErrorSurfacesRecorded = @($inventory.surfaces.logging).Count -gt 0 -and @($inventory.surfaces.errorResponses).Count -gt 0
    missingDurableMessagingNotMisrepresented = -not $inventory.messagingCapabilities.durableOutboxImplemented -and -not $inventory.messagingCapabilities.durableInboxImplemented -and -not $inventory.messagingCapabilities.deadLetterOrQuarantineImplemented -and -not $inventory.messagingCapabilities.replayOrReprocessingImplemented
    legacyEventIdentityRecorded = $inventory.currentEventIdentity.eventIdType -eq 'Guid' -and $inventory.currentEventIdentity.occurredAtType -eq 'DateTime' -and -not $inventory.currentEventIdentity.fullEnvelopeImplemented
    fourSecurityFindingsOwned = @($inventory.findings).Count -eq 4 -and @($inventory.findings | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.severity) -or [string]::IsNullOrWhiteSpace($_.resolutionTrigger) }).Count -eq 0
    externalEvidenceGapsOwned = @($inventory.externalEvidenceGaps).Count -ge 3 -and @($inventory.externalEvidenceGaps | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) }).Count -eq 0
    phase0EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase0-baseline.md')
    phase0LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase0-layerguard-report.json')
    implementationPlanExists = Test-Path (Join-Path $repositoryRoot '.claude/Plans/20260908-g05-context-sensitive-data-boundary.md')
}

if ($Phase -ge 1) {
    $contextProject = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Platform/Context/IFX.Platform.Context.Contracts/IFX.Platform.Context.Contracts.csproj')
    $messagingProject = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj')
    $contextSource = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'src/Platform/Context/IFX.Platform.Context.Contracts') -File -Filter '*.cs' | Get-Content -Raw) -join "`n"
    $messagingSource = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Contracts') -File -Filter '*.cs' | Get-Content -Raw) -join "`n"
    $protocolPolicy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/context-protocol-v1.json') | ConvertFrom-Json -Depth 20
    $governance = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json') | ConvertFrom-Json -Depth 30
    $checks.protocolProjectsHaveNoDependencies = $contextProject -notmatch '(PackageReference|ProjectReference)' -and $messagingProject -notmatch '(PackageReference|ProjectReference)'
    $checks.contextStrongIdentifiersExist = $contextSource -match 'record struct CorrelationId' -and $contextSource -match 'record struct OperationId' -and $contextSource -match 'record struct CausationId' -and $contextSource -match 'record struct RequestId'
    $checks.explicitScopesExist = $contextSource -match 'record struct TenantScope' -and $contextSource -match 'record struct PlatformScope' -and $contextSource -match 'enum ExecutionScopeKind'
    $checks.minimumReferencesExist = $contextSource -match 'record ActorReference' -and $contextSource -match 'record SourceReference' -and $contextSource -match 'enum ContextProvenance'
    $checks.contractContextIsVersionedBclShape = $contextSource -match 'record ContractRequestContext' -and $protocolPolicy.contractRequestContext.version -eq 1
    $checks.eventEnvelopeIsVersionedBclShape = $messagingSource -match 'record EventEnvelope' -and $messagingSource -match 'DateTimeOffset OccurredAt' -and $protocolPolicy.eventEnvelope.version -eq 1
    $checks.noFrameworkOrTransportLeak = ($contextSource + $messagingSource) -notmatch 'Microsoft\.AspNetCore|ClaimsPrincipal|MediatR|EntityFrameworkCore|MassTransit|RabbitMQ|IServiceCollection'
    $checks.g03PrimitiveProjectsAdmitted = 'IFX.Platform.Context.Contracts' -in $governance.sharedPrimitiveProjects -and 'IFX.Platform.Messaging.Contracts' -in $governance.sharedPrimitiveProjects
    $checks.protocolContractTestsExist = Test-Path (Join-Path $repositoryRoot 'tests/IFX.Platform.ProtocolContracts.Tests/EventEnvelopeV1Tests.cs')
    $checks.phase1EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase1-protocol-primitives.md')
    $checks.phase1LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase1-layerguard-report.json')
}

if ($Phase -ge 2) {
    $applicationContextPath = Join-Path $repositoryRoot 'src/BuildingBlocks/IFX.BuildingBlocks.Application/Context'
    $applicationContextSource = @(Get-ChildItem -LiteralPath $applicationContextPath -File -Filter '*.cs' | Get-Content -Raw) -join "`n"
    $runtimeAccessorPath = Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/ExecutionContextAccessor.cs'
    $runtimeAccessorSource = Get-Content -Raw -LiteralPath $runtimeAccessorPath
    $programSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $currentUserSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/CurrentUser.cs')
    $sourcePolicy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/execution-context-sources.json') | ConvertFrom-Json -Depth 20
    $checks.applicationContextPortIsTransportNeutral = $applicationContextSource -match 'interface IExecutionContextAccessor' -and $applicationContextSource -match 'sealed record ExecutionContextSnapshot' -and $applicationContextSource -notmatch 'Microsoft\.AspNetCore|ClaimsPrincipal|HttpContext|MediatR'
    $checks.runtimeAccessorHasBoundedAsyncLocalLifetime = $runtimeAccessorSource -match 'AsyncLocal<ScopeFrame\?>' -and $runtimeAccessorSource -match 'using var scope = Push\(context\)' -and $runtimeAccessorSource -match 'ExecutionContext\.SuppressFlow\(\)' -and $runtimeAccessorSource -match 'disposed in reverse order'
    $checks.rootCompositionOwnsUniqueImplementation = ([regex]::Matches($programSource, 'AddSingleton<ExecutionContextAccessor>\(\)')).Count -eq 1 -and $programSource -match 'AddSingleton<IExecutionContextAccessor>' -and $programSource -match 'AddSingleton<IExecutionContextScopeFactory>'
    $checks.currentUserHttpResponsibilitiesAreSplit = $currentUserSource -notmatch 'IHttpContextAccessor|ClaimsPrincipal|HttpContext' -and (Test-Path (Join-Path $repositoryRoot 'src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/HttpIdentityFacts.cs')) -and (Test-Path (Join-Path $repositoryRoot 'src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/ExecutionTenantSelection.cs'))
    $checks.fiveExecutionSourcesHaveFailClosedRules = @($sourcePolicy.sources).Count -eq 5 -and @($sourcePolicy.sources | Where-Object { [string]::IsNullOrWhiteSpace($_.source) -or [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.actorRule) -or [string]::IsNullOrWhiteSpace($_.scopeRule) -or [string]::IsNullOrWhiteSpace($_.sourceRule) -or [string]::IsNullOrWhiteSpace($_.builderBoundary) -or [string]::IsNullOrWhiteSpace($_.missingContextBehavior) }).Count -eq 0
    $checks.executionContextIsolationTestsExist = Test-Path (Join-Path $repositoryRoot 'tests/IFX.IntegrationTests/Runtime/ExecutionContextAccessorTests.cs')
    $checks.authFactSplitTestsExist = Test-Path (Join-Path $repositoryRoot 'tests/IFX.Modules.Auth.Infrastructure.Tests/Authorization/HttpContextFactTests.cs')
    $checks.phase2EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase2-execution-context.md')
    $checks.phase2LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase2-layerguard-report.json')
}

if ($Phase -ge 3) {
    $programSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $correlationSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Middleware/HttpCorrelationMiddleware.cs')
    $traceSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Middleware/HttpTraceContextMiddleware.cs')
    $httpContextSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Middleware/HttpExecutionContextMiddleware.cs')
    $exceptionSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Middleware/ExceptionHandlingMiddleware.cs')
    $appSettings = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/appsettings.json') | ConvertFrom-Json -Depth 20
    $presentationSource = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'src/Modules') -Recurse -File -Filter '*.cs' | Where-Object { $_.FullName -match '\.Presentation' } | Get-Content -Raw) -join "`n"
    $middlewareOrder = @(
        $programSource.IndexOf('UseMiddleware<ExceptionHandlingMiddleware>'),
        $programSource.IndexOf('UseMiddleware<HttpTraceContextMiddleware>'),
        $programSource.IndexOf('UseMiddleware<HttpCorrelationMiddleware>'),
        $programSource.IndexOf('UseMiddleware<RequestLoggingMiddleware>'),
        $programSource.IndexOf('UseAuthentication()'),
        $programSource.IndexOf('UseMiddleware<HttpExecutionContextMiddleware>'),
        $programSource.IndexOf('UseAuthorization()'))
    $checks.httpMiddlewareOrderIsDeterministic = $middlewareOrder -notcontains -1 -and ($middlewareOrder -join ',') -eq (($middlewareOrder | Sort-Object) -join ',')
    $checks.publicCorrelationAndTrustedGatewayRulesExist = $correlationSource -match 'X-Client-Request-Id' -and $correlationSource -match 'Guid\.NewGuid\(\)' -and $correlationSource -match 'AllowTrustedGatewayCorrelationPropagation' -and $correlationSource -match 'IsTrustedGateway' -and -not $appSettings.HttpContextBoundary.AllowTrustedGatewayCorrelationPropagation
    $checks.w3cTraceRestartIsNonBlocking = $traceSource -match 'ActivityContext\.TryParse' -and $traceSource -match 'ActivityIdFormat\.W3C' -and $traceSource -match 'invalidInboundTrace'
    $checks.tenantParsingFailsClosed = $httpContextSource -match 'GetCommaSeparatedValues\("X-Tenant-Id"\)' -and $httpContextSource -match 'tenant_context_invalid' -and $httpContextSource -match 'tenant_access_denied' -and $httpContextSource -match 'tenant_context_required' -and $httpContextSource -match 'PrimaryTenantId' -and $httpContextSource -match 'IsGlobalAdmin'
    $groupCount = ([regex]::Matches($presentationSource, 'MapGroup\(')).Count
    $scopeMetadataCount = ([regex]::Matches($presentationSource, 'WithMetadata\(ExecutionScopeRequirement\.(Tenant|Platform|Public)\)')).Count
    $checks.allModuleRouteGroupsDeclareScopeMetadata = $groupCount -gt 10 -and $groupCount -eq $scopeMetadataCount -and $programSource -match 'WithMetadata\(ExecutionScopeRequirement\.Platform\)'
    $checks.safeStableHttpErrorsExist = $exceptionSource -match 'ErrorCode' -and $exceptionSource -match 'CorrelationId' -and $exceptionSource -notmatch 'response\.Error = exception\.Message' -and $exceptionSource -notmatch '\{Message\}.*ex\.Message'
    $checks.currentUserTenantComesFromExecutionContext = (Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/ExecutionTenantSelection.cs')) -match 'IExecutionContextAccessor'
    $checks.phase3HttpIntegrationTestsExist = Test-Path (Join-Path $repositoryRoot 'tests/IFX.IntegrationTests/Middleware/HttpContextBoundaryTests.cs')
    $checks.phase3EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase3-http-boundary.md')
    $checks.phase3LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase3-layerguard-report.json')
}

if ($Phase -ge 4) {
    $conformancePolicy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/contract-context-conformance-v1.json') | ConvertFrom-Json -Depth 20
    $conformanceTests = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/IFX.Platform.ProtocolContracts.Tests/ContractContextConformanceTests.cs')
    $contractContextSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Platform/Context/IFX.Platform.Context.Contracts/ContractRequestContext.cs')
    $expectedValidationOrder = @('consumerAllowlist', 'version', 'scope', 'actorSource', 'tenantResource')
    $expectedResults = @('contract_context_invalid', 'contract_consumer_denied', 'contract_tenant_mismatch', 'contract_timeout', 'contract_cancelled', 'contract_unavailable')
    $checks.consumerContextConstructionIsExplicit = $conformancePolicy.consumerConstruction.requestId -match 'every invocation' -and $conformancePolicy.consumerConstruction.correlationId -match 'ExecutionContext' -and $conformancePolicy.consumerConstruction.causationId -match 'operation identifier' -and $conformanceTests -match 'Guid\.NewGuid\(\)' -and $conformanceTests -match 'executionContext\.OperationId\.Value'
    $checks.providerValidationOrderIsFixed = (@($conformancePolicy.providerValidationOrder) -join ',') -eq ($expectedValidationOrder -join ',') -and $conformanceTests -match 'ValidationTrace\.Add\("consumerAllowlist"\)' -and $conformanceTests -match 'ValidationTrace\.Add\("tenantResource"\)'
    $checks.contractFailureResultsAreStable = @($expectedResults | Where-Object { $_ -notin $conformancePolicy.stableResults }).Count -eq 0 -and @($expectedResults | Where-Object { $conformanceTests -notmatch [regex]::Escape($_) }).Count -eq 0
    $checks.fakeCarriersShareOneApplicationPort = $conformanceTests -match 'interface IAccountCompliancePort' -and $conformanceTests -match 'DirectContractCarrier' -and $conformanceTests -match 'JsonRoundTripContractCarrier' -and $conformanceTests -match 'CarrierSubstitution_DoesNotChangeConsumerApplicationPort'
    $checks.contractContextCarriesNoCallerAuthorization = $contractContextSource -notmatch 'public .*?(Token|ClaimsPrincipal|Roles|Permissions|AuthorizationGranted)' -and $conformanceTests -match 'ContractRequestContext_HasNoCallerAssertedSecurityPayload' -and @($conformancePolicy.consumerConstruction.forbidden).Count -eq 5
    $checks.plan01ContractContextHandoffExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/handoffs/plan01-contract-context-handoff.md')
    $checks.realContractCarrierNotMisrepresented = $conformancePolicy.status -eq 'pre-active-conformance' -and $conformancePolicy.realCarrierEvidence -match 'required from Plan 01'
    $checks.phase4EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase4-contract-context.md')
    $checks.phase4LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase4-layerguard-report.json')
}

if ($Phase -ge 5) {
    $eventPolicy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/event-propagation-conformance-v1.json') | ConvertFrom-Json -Depth 20
    $eventSchema = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/schemas/event-envelope-v1.schema.json') | ConvertFrom-Json -Depth 20
    $eventFixture = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/fixtures/event-envelope-v1.golden.json') | ConvertFrom-Json -Depth 20
    $eventTests = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tests/IFX.Platform.ProtocolContracts.Tests/EventPropagationConformanceTests.cs')
    $requiredEnvelopeFields = @('envelopeVersion', 'eventId', 'eventType', 'schemaVersion', 'occurredAt', 'producer', 'scope', 'correlationId', 'causationId', 'contentType', 'provenance')
    $expectedConsumerOrder = @('producerAllowlist', 'envelopeAndSchemaVersion', 'eventIdentity', 'scopeAndTenant', 'correlationAndCausation', 'contentType', 'trace')
    $checks.eventEnvelopeSchemaAndGoldenExist = $eventSchema.'$id' -eq 'urn:ifx:messaging:event-envelope:v1' -and @($requiredEnvelopeFields | Where-Object { $_ -notin $eventSchema.required }).Count -eq 0 -and $eventSchema.additionalProperties -and $eventFixture.envelopeVersion -eq 1 -and $eventFixture.eventType -match '^ifx\..+\.v1$'
    $checks.eventProducerUsesTrustedExecutionContext = $eventPolicy.producerConstruction.producer -match 'trusted runtime' -and $eventTests -match 'ConformanceEventProducer' -and $eventTests -match 'context\.CorrelationId\.Value' -and $eventTests -match 'context\.OperationId\.Value'
    $checks.outboxLogicalAndDeliveryDataAreSeparated = (@($eventPolicy.physicalSeparation.immutableLogical) -join ',') -eq 'envelope,payload' -and @($eventPolicy.physicalSeparation.mutableDelivery).Count -eq 4 -and $eventTests -match 'class FakeOutboxRecord' -and $eventTests -match 'class EventDeliveryMetadata'
    $checks.transportMappingAndConsumerOrderAreFixed = @($eventPolicy.transportHeaders).Count -eq 14 -and (@($eventPolicy.consumerValidationOrder) -join ',') -eq ($expectedConsumerOrder -join ',') -and $eventTests -match 'static class FakeEventDispatcher' -and $eventTests -match 'class FakeInboundEventAdapter'
    $checks.consumerEventExecutionSemanticsAreExplicit = $eventPolicy.consumerExecution.operationId -eq 'inbound EventId' -and $eventPolicy.consumerExecution.causationId -match 'inbound EventId' -and $eventTests -match 'new OperationId\(eventId\)' -and $eventTests -match 'new CausationId\(eventId\)'
    $checks.retryReplayTraceAndTenantConformanceExist = $eventTests -match 'RetryAndReplay_PreserveLogicalEnvelopeAndPayload' -and $eventTests -match 'InvalidTrace_RestartsTraceWithoutRejectingBusinessEvent' -and $eventTests -match 'InvalidTenant_IsQuarantinedBeforeInboxOrApplication'
    $checks.plan02EventContextHandoffExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/handoffs/plan02-event-context-handoff.md')
    $checks.realMessagingDurabilityNotMisrepresented = $eventPolicy.status -eq 'pre-active-fake-carrier-conformance' -and $eventPolicy.realDurabilityEvidence -match 'required from Plan 02'
    $checks.phase5EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase5-event-propagation.md')
    $checks.phase5LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase5-layerguard-report.json')
}

if ($Phase -ge 6) {
    $catalogPath = Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 100
    $catalogReport = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase6-catalog-report.json') | ConvertFrom-Json -Depth 100
    $layerGuardInput = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json') | ConvertFrom-Json -Depth 100
    $classifiedFields = @()
    foreach ($surface in @($catalog.fieldSurfaces)) {
        $fields = if ($surface.fieldsFromProtocol) { @(($catalog.protocols | Where-Object identity -eq $surface.id | Select-Object -First 1).fields) } else { @($surface.fields) }
        $classifiedFields += @($fields | ForEach-Object { [ordered]@{ surface = $surface.id; name = $_.name; classification = $_.classification; exceptionRef = $_.exceptionRef } })
    }
    $denylistText = @($catalog.fieldGovernance.c4Denylist) -join '|'
    $checks.g03CatalogRemainsSoleFieldAuthority = $catalog.fieldGovernance.authority -match 'sole admission source' -and $catalogReport.result -eq 'passed' -and $catalogReport.checks.sensitiveFieldGovernance
    $checks.allTargetLegacyAndEnvelopeFieldsAreClassified = @($catalog.fieldSurfaces).Count -eq 32 -and @($classifiedFields).Count -eq 167 -and @($catalog.fieldSurfaces | Where-Object kind -like 'legacy-*').Count -eq 27 -and @($catalog.publicSurface | Where-Object kind -in @('dto', 'integration-event')).Count -eq 27
    $checks.noC4AndAllC3HaveGovernedExceptions = @($classifiedFields | Where-Object classification -eq 'C4').Count -eq 0 -and @($classifiedFields | Where-Object { $_.classification -eq 'C3' -and [string]::IsNullOrWhiteSpace($_.exceptionRef) }).Count -eq 0 -and @($catalog.fieldExceptions).Count -eq 8
    $checks.c4SemanticDenylistIsComplete = @('password', 'token', 'authorization', 'cookie', 'otp', 'api secret', 'client secret', 'private key', 'connection string' | Where-Object { $denylistText -notmatch [regex]::Escape($_) }).Count -eq 0
    $checks.capabilitySplitAndEventMinimizationAreRecorded = @($catalog.migrationRecommendations).Count -ge 2 -and @($catalog.eventMinimizationReviews).Count -ge 5 -and 'crm.dto.investor-summary' -in @($catalog.migrationRecommendations.surfaceId)
    $checks.sensitiveFinancialAndComplianceUsesAreGoverned = @($catalog.sensitiveUsePolicies).Count -eq 2 -and @($catalog.sensitiveUsePolicies | Where-Object { [string]::IsNullOrWhiteSpace($_.encryption) -or [string]::IsNullOrWhiteSpace($_.access) -or [string]::IsNullOrWhiteSpace($_.retention) -or [string]::IsNullOrWhiteSpace($_.deletion) -or [string]::IsNullOrWhiteSpace($_.replay) }).Count -eq 0
    $checks.pendingSecurityApprovalIsNotMisrepresented = @($catalog.fieldExceptions | Where-Object approvalStatus -eq 'Approved').Count -eq 0 -and @($catalog.fieldExceptions | Where-Object { $_.approvalStatus -notin @('Pending', 'PendingRemoval') }).Count -eq 0
    $checks.layerGuardGovernanceHashMatchesCatalog = $layerGuardInput.catalogSha256 -eq (Get-FileHash -Algorithm SHA256 -LiteralPath $catalogPath).Hash.ToLowerInvariant()
    $checks.phase6EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase6-field-classification.md')
    $checks.phase6LayerGuardEvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G05/G05-phase6-layerguard-report.json')
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G05'
    phase = $Phase
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    checks = $checks
    sha256 = [ordered]@{ inventory = $secondHash }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G05 Phase $Phase guard failed. Report: $resolvedReportPath" }
Write-Host "G05 Phase $Phase guard passed. Report: $resolvedReportPath"
