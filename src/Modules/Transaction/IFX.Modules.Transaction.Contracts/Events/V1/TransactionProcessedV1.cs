using IFX.Platform.Messaging.Contracts.Events;

namespace IFX.Modules.Transaction.Contracts.V1.Events;

public sealed record TransactionProcessedV1(
    Guid TransactionId,
    string TransactionType,
    Guid InvestmentAccountId,
    Guid ClassId,
    Guid? TargetClassId,
    decimal Units,
    decimal NavPrice) : IIntegrationEventV1
{
    public const string EventType = "ifx.transaction.transaction-processed.v1";
    public const int SchemaVersion = 1;
}
