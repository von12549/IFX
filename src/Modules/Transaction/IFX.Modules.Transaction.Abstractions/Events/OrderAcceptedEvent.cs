using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record OrderAcceptedEvent(
    Guid OrderId,
    Guid TenantId,
    string DealReference
) : IntegrationEvent;
