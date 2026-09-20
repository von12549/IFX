[CmdletBinding()]
param(
    [string]$ReportPath = 'docs/architecture/review/evidence/gates/G05/G05-context-inventory.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../../..')) }
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$sourceRoot = Join-Path $repositoryRoot 'src'

function Get-RelativePath([string]$Path) {
    [System.IO.Path]::GetRelativePath($repositoryRoot, $Path).Replace('\', '/')
}

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.cs' |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
    Sort-Object FullName)

function Find-Surface([string]$Category, [string]$Pattern, [System.IO.FileInfo[]]$Files = $sourceFiles) {
    $items = foreach ($file in $Files) {
        foreach ($match in @(Select-String -LiteralPath $file.FullName -Pattern $Pattern -AllMatches)) {
            [pscustomobject][ordered]@{
                category = $Category
                path = Get-RelativePath $file.FullName
                line = $match.LineNumber
            }
        }
    }
    @($items | Sort-Object path, line -Unique)
}

$protocolFiles = @($sourceFiles | Where-Object {
        $_.FullName -match '[\\/](IFX\.[^\\/]+\.(Abstractions|Contracts)|App\.Abstractions)[\\/]' -or
        $_.FullName -match '[\\/]Platform[\\/]Messaging[\\/]IFX\.Platform\.Messaging\.Abstractions[\\/]'
    })

$protocolSchemas = foreach ($file in $protocolFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    $types = @([regex]::Matches($content, '\bpublic\s+(?:(?:sealed|abstract)\s+)?(?:class|record|interface)\s+([A-Za-z_][A-Za-z0-9_]*)') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $properties = @([regex]::Matches($content, '\bpublic\s+[A-Za-z0-9_\.<>\?,\[\]\s]+\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{\s*get') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $primaryRecord = [regex]::Match(
        $content,
        '\bpublic\s+(?:(?:sealed|abstract)\s+)?record(?:\s+class)?\s+[A-Za-z_][A-Za-z0-9_]*\s*\((.*?)\)\s*(?::|;)',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($primaryRecord.Success) {
        $recordProperties = foreach ($parameter in ($primaryRecord.Groups[1].Value -split ',')) {
            $withoutComment = ($parameter -replace '//.*', '').Trim()
            if ($withoutComment -match '[A-Za-z_][A-Za-z0-9_\.<>\?\[\]]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:=.*)?$') {
                $Matches[1]
            }
        }
        $properties = @($properties + $recordProperties | Sort-Object -Unique)
    }
    if ($types.Count -gt 0 -or $properties.Count -gt 0) {
        [ordered]@{
            path = Get-RelativePath $file.FullName
            types = $types
            publicProperties = $properties
        }
    }
}

$sensitivePropertyNames = '(?i)(Name|Email|Issuer|Subject|IpAddress|UserId|TenantId|ResourceId|AccountNumber|Code|Reason|Amount|Units|Nav|TaxResiden|Password|Token|Authorization|Cookie|Otp|Secret|PrivateKey|ConnectionString)'
$sensitiveProtocolFields = foreach ($schema in $protocolSchemas) {
    foreach ($property in @($schema.publicProperties | Where-Object { $_ -match $sensitivePropertyNames })) {
        [ordered]@{ path = $schema.path; property = $property }
    }
}

$eventFiles = @($sourceFiles | Where-Object { $_.FullName -match '[\\/]Events[\\/].*Event\.cs$' -or $_.Name -in @('IIntegrationEvent.cs', 'IntegrationEvent.cs') })
$outboxFiles = @($sourceFiles | Where-Object { $_.FullName -match '[\\/]Outbox[\\/]' -or $_.Name -match '^Outbox.*\.cs$' })
$inboxFiles = @($sourceFiles | Where-Object { $_.FullName -match '[\\/]Inbox[\\/]' -or $_.Name -match '^Inbox.*\.cs$' })
$deadLetterFiles = @($sourceFiles | Where-Object { $_.Name -match 'DeadLetter|Quarantine' })
$replayFiles = @($sourceFiles | Where-Object { $_.Name -match 'Replay|Reprocessing' })

$report = [ordered]@{
    formatVersion = 1
    gate = 'G05'
    inventoryPolicy = 'source-locations-and-schema-names-only-no-runtime-values'
    source = [ordered]@{
        csFiles = $sourceFiles.Count
        publicProtocolFiles = $protocolFiles.Count
        eventFiles = $eventFiles.Count
    }
    surfaces = [ordered]@{
        httpHeaders = @(Find-Surface 'http-header' 'Headers\[|GetTypedHeaders|X-Tenant-Id|traceparent|tracestate')
        middleware = @(Find-Surface 'middleware' 'UseMiddleware<|class\s+\w*Middleware\b')
        claimsAndCurrentUser = @(Find-Surface 'claims-current-user' 'ICurrentUser|ClaimsPrincipal|ClaimsTransformation|FindFirst|FindAll')
        scopedJobsAndHandlers = @(Find-Surface 'job-handler-scope' 'BackgroundService|IHostedService|IRequestHandler<|IIntegrationEventHandler<')
        logging = @(Find-Surface 'logging-call' '\.(LogTrace|LogDebug|LogInformation|LogWarning|LogError|LogCritical|BeginScope)\(')
        tracingAndMetrics = @(Find-Surface 'trace-metric' 'Activity(Source)?\b|Meter\b|Counter<|Histogram<|AddTag\(|SetTag\(')
        errorResponses = @(Find-Surface 'error-response' 'ErrorResponse|Problem\(|Results\.(BadRequest|Unauthorized|Forbidden|NotFound|Problem)|response\.Error\s*=')
        diagnostics = @(Find-Surface 'diagnostic-endpoint' 'health/details|management/runtime|UseHangfireDashboard|MapHealthChecks')
        rawExceptionExposure = @(Find-Surface 'raw-exception-exposure' 'response\.Error\s*=\s*exception\.Message|\{Message\}.*ex\.Message')
        tokenPersistence = @(Find-Surface 'token-persistence' 'LoginEvent|builder\.Property\(.*(AccessToken|RefreshToken)|AccessToken\s*\{\s*get;\s*private set;|RefreshToken\s*\{\s*get;\s*private set;')
    }
    publicSchemas = @($protocolSchemas | Sort-Object path)
    sensitiveProtocolFields = @($sensitiveProtocolFields | Sort-Object path, property)
    messagingCapabilities = [ordered]@{
        inMemoryBus = Test-Path (Join-Path $sourceRoot 'Platform/Messaging/IFX.Platform.Messaging.Infrastructure.InMemory/InMemoryIntegrationEventBus.cs')
        durableOutboxImplemented = $outboxFiles.Count -gt 0
        durableInboxImplemented = $inboxFiles.Count -gt 0
        deadLetterOrQuarantineImplemented = $deadLetterFiles.Count -gt 0
        replayOrReprocessingImplemented = $replayFiles.Count -gt 0
        outboxSourceFiles = @($outboxFiles | ForEach-Object { Get-RelativePath $_.FullName } | Sort-Object)
        inboxSourceFiles = @($inboxFiles | ForEach-Object { Get-RelativePath $_.FullName } | Sort-Object)
    }
    currentEventIdentity = [ordered]@{
        interfacePath = 'src/Platform/Messaging/IFX.Platform.Messaging.Abstractions/IIntegrationEvent.cs'
        baseTypePath = 'src/Platform/Messaging/IFX.Platform.Messaging.Abstractions/IntegrationEvent.cs'
        eventIdType = 'Guid'
        occurredAtType = 'DateTime'
        eventIdCreation = 'Guid.NewGuid'
        occurredAtCreation = 'DateTime.UtcNow'
        fullEnvelopeImplemented = $false
    }
    findings = @(
        [ordered]@{ id = 'G05-F01'; severity = 'critical'; owner = 'Auth and Security'; summary = 'Access and refresh token fields are persisted on LoginEvent'; resolutionTrigger = 'Remove persisted C4 values and apply a module-owned migration before Gate closure' },
        [ordered]@{ id = 'G05-F02'; severity = 'high'; owner = 'ApiHost and Auth'; summary = 'Explicit invalid tenant header can fall back to the primary tenant'; resolutionTrigger = 'Phase 3 fail-closed tenant middleware and integration tests' },
        [ordered]@{ id = 'G05-F03'; severity = 'high'; owner = 'Module owners and Security'; summary = 'Operational logs include raw direct or linkable identifiers'; resolutionTrigger = 'Phase 7 sink policy and sentinel tests' },
        [ordered]@{ id = 'G05-F04'; severity = 'high'; owner = 'ApiHost'; summary = 'Some external errors and unhandled logs use raw exception messages'; resolutionTrigger = 'Phase 7 stable error schema and captured-sink tests' }
    )
    externalEvidenceGaps = @(
        [ordered]@{ id = 'G05-X01'; owner = 'Security'; evidence = 'Approved classification and exception review for every C3 field' },
        [ordered]@{ id = 'G05-X02'; owner = 'Operations and Security'; evidence = 'Production sink, retention, pseudonym-key and access-control configuration' },
        [ordered]@{ id = 'G05-X03'; owner = 'Plan 01 and Plan 02 owners'; evidence = 'Real Contract and durable Event carrier conformance reruns' }
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
Write-Host "G05 context inventory generated: $resolvedReportPath"
