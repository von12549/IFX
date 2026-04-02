using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record TransactionCancelledEvent(
    Guid TransactionId,
    Guid TenantId
) : IntegrationEvent;
