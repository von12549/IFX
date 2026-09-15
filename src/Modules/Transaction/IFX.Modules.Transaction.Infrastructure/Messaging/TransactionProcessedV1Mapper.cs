using IFX.Modules.Transaction.Application.Events;
using IFX.Modules.Transaction.Contracts.V1.Events;

namespace IFX.Modules.Transaction.Infrastructure.Messaging;

public static class TransactionProcessedV1Mapper
{
    public static TransactionProcessedV1 Map(TransactionProcessed fact) => new(
        fact.TransactionId,
        fact.TransactionType,
        fact.InvestmentAccountId,
        fact.ClassId,
        fact.TargetClassId,
        fact.Units,
        fact.NavPrice);
}
