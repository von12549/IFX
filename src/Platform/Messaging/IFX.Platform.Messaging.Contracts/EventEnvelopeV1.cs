using System.Text.RegularExpressions;

namespace IFX.Platform.Messaging.Contracts.Messaging;

public sealed partial record EventEnvelope
{
    public const int CurrentVersion = 1;
    public const string JsonContentType = "application/json";
    public const string TenantScope = "tenant";
    public const string PlatformScope = "platform";
    public const string TrustedProvenance = "trusted";
    public const string SynthesizedProvenance = "synthesized";

    public EventEnvelope(
        Guid eventId,
        string eventType,
        int schemaVersion,
        DateTimeOffset occurredAt,
        string producer,
        string scope,
        Guid? tenantId,
        Guid correlationId,
        Guid causationId,
        string contentType = JsonContentType,
        string? traceParent = null,
        string? traceState = null,
        string provenance = TrustedProvenance,
        int envelopeVersion = CurrentVersion)
    {
        ArgumentNullException.ThrowIfNull(eventType);
        ArgumentNullException.ThrowIfNull(producer);

        EventId = RequireIdentifier(eventId, nameof(eventId));
        CorrelationId = RequireIdentifier(correlationId, nameof(correlationId));
        CausationId = RequireIdentifier(causationId, nameof(causationId));

        var identity = EventTypePattern().Match(eventType);
        if (!identity.Success || !int.TryParse(identity.Groups[1].Value, out var suffixVersion) || suffixVersion != schemaVersion)
        {
            throw new ArgumentException("EventType must be lowercase, end in .vN and match SchemaVersion.", nameof(eventType));
        }

        if (occurredAt.Offset != TimeSpan.Zero)
        {
            throw new ArgumentException("OccurredAt must be UTC DateTimeOffset.", nameof(occurredAt));
        }

        if (!ProducerPattern().IsMatch(producer))
        {
            throw new ArgumentException("Producer must be a lowercase trusted runtime identity.", nameof(producer));
        }

        if (scope == TenantScope)
        {
            TenantId = tenantId is { } value && value != Guid.Empty
                ? value
                : throw new ArgumentException("Tenant scope requires a non-empty TenantId.", nameof(tenantId));
        }
        else if (scope == PlatformScope)
        {
            if (tenantId is not null)
            {
                throw new ArgumentException("Platform scope cannot carry a TenantId.", nameof(tenantId));
            }
        }
        else
        {
            throw new ArgumentException("Scope must be tenant or platform.", nameof(scope));
        }

        if (!string.Equals(contentType, JsonContentType, StringComparison.Ordinal))
        {
            throw new ArgumentException($"Event Envelope V1 content type must be {JsonContentType}.", nameof(contentType));
        }

        if (traceParent is not null)
        {
            ValidateTrace(traceParent, traceState);
        }
        else if (traceState is not null)
        {
            throw new ArgumentException("TraceState cannot exist without TraceParent.", nameof(traceState));
        }

        if (provenance is not (TrustedProvenance or SynthesizedProvenance) || envelopeVersion != CurrentVersion)
        {
            throw new ArgumentException("Envelope provenance or version is not supported.");
        }

        EventType = eventType;
        SchemaVersion = schemaVersion;
        OccurredAt = occurredAt;
        Producer = producer;
        Scope = scope;
        ContentType = contentType;
        TraceParent = traceParent;
        TraceState = traceState;
        Provenance = provenance;
        EnvelopeVersion = envelopeVersion;
    }

    public int EnvelopeVersion { get; }
    public Guid EventId { get; }
    public string EventType { get; }
    public int SchemaVersion { get; }
    public DateTimeOffset OccurredAt { get; }
    public string Producer { get; }
    public string Scope { get; }
    public Guid? TenantId { get; }
    public Guid CorrelationId { get; }
    public Guid CausationId { get; }
    public string ContentType { get; }
    public string? TraceParent { get; }
    public string? TraceState { get; }
    public string Provenance { get; }

    private static Guid RequireIdentifier(Guid value, string parameterName) => value == Guid.Empty
        ? throw new ArgumentException("Envelope identifier cannot be empty.", parameterName)
        : value;

    private static void ValidateTrace(string traceParent, string? traceState)
    {
        var match = TraceParentPattern().Match(traceParent);
        if (!match.Success || match.Groups[1].Value.All(character => character == '0') || match.Groups[2].Value.All(character => character == '0'))
        {
            throw new ArgumentException("TraceParent must be a valid lowercase W3C traceparent value.", nameof(traceParent));
        }

        if (traceState is { Length: > 256 } || traceState?.Any(character => character < 0x20 || character > 0x7e) == true)
        {
            throw new ArgumentException("TraceState is not a valid bounded ASCII value.", nameof(traceState));
        }
    }

    [GeneratedRegex(@"^ifx\.[a-z0-9-]+(?:\.[a-z0-9-]+)+\.v([1-9][0-9]*)$", RegexOptions.CultureInvariant)]
    private static partial Regex EventTypePattern();

    [GeneratedRegex("^[a-z0-9][a-z0-9.-]{0,126}[a-z0-9]$|^[a-z0-9]$", RegexOptions.CultureInvariant)]
    private static partial Regex ProducerPattern();

    [GeneratedRegex("^00-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$", RegexOptions.CultureInvariant)]
    private static partial Regex TraceParentPattern();
}
