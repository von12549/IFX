using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record TransactionCreatedEvent(
    Guid TransactionId,
    Guid TenantId,
    string TransactionType,
    Guid InvestmentAccountId,
    Guid ClassId,
    decimal Amount
) : IntegrationEvent;
