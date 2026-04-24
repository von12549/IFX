using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record OrderSubmittedEvent(
    Guid OrderId,
    Guid TenantId,
    string OrderType,
    string OrderReference,
    int LegCount
) : IntegrationEvent;
