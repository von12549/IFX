using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Transaction.Abstractions.Events;

public record TransactionProcessedEvent(
    Guid TransactionId,
    Guid TenantId,
    string TransactionType,       // "Subscription" | "Redemption" | "Transfer" | "Switch"
    Guid InvestmentAccountId,
    Guid ClassId,
    Guid? TargetClassId,          // populated for Transfer/Switch
    decimal Units,
    decimal NAVPrice
) : IntegrationEvent;
