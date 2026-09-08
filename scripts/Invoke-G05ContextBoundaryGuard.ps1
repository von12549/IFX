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
