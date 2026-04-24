using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record OrderConfirmedEvent(
    Guid OrderId,
    Guid TenantId,
    string OrderType,
    Guid InvestmentAccountId
) : IntegrationEvent;
