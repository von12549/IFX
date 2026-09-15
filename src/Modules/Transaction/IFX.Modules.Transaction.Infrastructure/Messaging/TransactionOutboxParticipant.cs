using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Transaction.Application.Events;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.Platform.Messaging.Runtime;

namespace IFX.Modules.Transaction.Infrastructure.Messaging;

public sealed class TransactionOutboxParticipant(
    TransactionDbContext dbContext,
    IPendingIntegrationEventSource eventSource,
    IOutboxMessageFactory messageFactory,
    IExecutionContextAccessor executionContext) : ITransactionParticipant
{
    public Task PrepareAsync(object command, object? response, CancellationToken cancellationToken)
    {
        var pending = eventSource.Drain();
        if (pending.Count == 0) return Task.CompletedTask;
        if (!executionContext.HasCurrent || executionContext.Current.TenantId is not { } tenantId)
        {
            throw new InvalidOperationException("A trusted tenant execution context is required to persist Transaction Outbox messages.");
        }

        foreach (var payload in pending)
        {
            if (payload is not TransactionProcessed fact)
            {
                throw new InvalidOperationException($"Transaction emitted an unregistered integration event '{payload.GetType().FullName}'.");
            }

            var transactionProcessed = TransactionProcessedV1Mapper.Map(fact);
            var logical = messageFactory.Create(transactionProcessed, "ifx.transaction", TransactionProcessedV1.EventType, TransactionProcessedV1.SchemaVersion, tenantId);
            var sequence = DateTimeOffset.UtcNow.UtcTicks;
            dbContext.OutboxMessages.Add(TransactionOutboxStore.ToEntity(logical, transactionProcessed.TransactionId.ToString("D"), sequence));
        }

        return Task.CompletedTask;
    }
}
