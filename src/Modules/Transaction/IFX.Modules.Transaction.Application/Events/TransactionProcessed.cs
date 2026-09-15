namespace IFX.Modules.Transaction.Application.Events;

public sealed record TransactionProcessed(
    Guid TransactionId,
    string TransactionType,
    Guid InvestmentAccountId,
    Guid ClassId,
    Guid? TargetClassId,
    decimal Units,
    decimal NavPrice);
