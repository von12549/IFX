using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record OrderRejectedEvent(
    Guid OrderId,
    Guid TenantId,
    string RejectionReason
) : IntegrationEvent;
