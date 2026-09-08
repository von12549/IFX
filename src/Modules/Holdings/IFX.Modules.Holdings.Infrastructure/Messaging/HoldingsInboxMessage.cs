namespace IFX.Modules.Holdings.Infrastructure.Messaging;

public sealed class HoldingsInboxMessage
{
    public Guid Id { get; set; }
    public string ConsumerId { get; set; } = string.Empty;
    public Guid EventId { get; set; }
    public Guid TenantId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public DateTimeOffset CompletedAt { get; set; }
}

public sealed class HoldingsQuarantinedMessage
{
    public Guid Id { get; set; }
    public Guid? EventId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string ReasonCode { get; set; } = string.Empty;
    public DateTimeOffset QuarantinedAt { get; set; }
}
