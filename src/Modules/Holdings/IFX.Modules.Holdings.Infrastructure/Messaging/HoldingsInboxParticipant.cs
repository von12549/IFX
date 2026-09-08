using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Application.Results;
using IFX.Modules.Holdings.Infrastructure.Persistence;

namespace IFX.Modules.Holdings.Infrastructure.Messaging;

public sealed class HoldingsInboxParticipant(HoldingsDbContext dbContext) : ITransactionParticipant
{
    public Task PrepareAsync(object command, object? response, CancellationToken cancellationToken)
    {
        if (command is IInboxCommand inboxCommand &&
            response is IInboxOperationResult { WasDuplicate: false } &&
            response is IOperationResult { IsSuccess: true })
        {
            dbContext.InboxMessages.Add(new HoldingsInboxMessage
            {
                Id = Guid.NewGuid(),
                ConsumerId = inboxCommand.ConsumerId,
                EventId = inboxCommand.Metadata.EventId,
                TenantId = inboxCommand.Metadata.TenantId,
                EventType = command.GetType().Name,
                CompletedAt = DateTimeOffset.UtcNow
            });
        }
        return Task.CompletedTask;
    }
}
