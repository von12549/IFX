namespace IFX.Modules.Registry.Infrastructure.Messaging;

public sealed class RegistryOutboxMessage
{
    public Guid EventId { get; set; }
    public int EnvelopeVersion { get; set; }
    public string EventType { get; set; } = string.Empty;
    public int SchemaVersion { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public string Producer { get; set; } = string.Empty;
    public string Scope { get; set; } = string.Empty;
    public Guid? TenantId { get; set; }
    public Guid CorrelationId { get; set; }
    public Guid CausationId { get; set; }
    public string ContentType { get; set; } = string.Empty;
    public string? TraceParent { get; set; }
    public string? TraceState { get; set; }
    public string Provenance { get; set; } = string.Empty;
    public string Payload { get; set; } = string.Empty;
    public string PartitionKey { get; set; } = string.Empty;
    public long Sequence { get; set; }
    public string State { get; set; } = OutboxStates.Pending;
    public int AttemptCount { get; set; }
    public DateTimeOffset NextAttemptAt { get; set; }
    public string? LeaseOwner { get; set; }
    public DateTimeOffset? LeaseUntil { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? DeliveredAt { get; set; }
    public string? LastErrorCode { get; set; }
    public byte[] ConcurrencyToken { get; set; } = [];
}

internal static class OutboxStates
{
    public const string Pending = "Pending";
    public const string Delivered = "Delivered";
    public const string DeadLettered = "DeadLettered";
}
