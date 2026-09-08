using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Application.Events;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Registry.Contracts.V1.Events;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Platform.Messaging.Runtime;

namespace IFX.Modules.Registry.Infrastructure.Messaging;

public sealed class RegistryOutboxParticipant(
    RegistryDbContext dbContext,
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
            throw new InvalidOperationException("A trusted tenant execution context is required to persist Registry Outbox messages.");
        }

        foreach (var payload in pending)
        {
            if (payload is not ClassStatusChangedV1 classStatusChanged)
            {
                throw new InvalidOperationException($"Registry emitted an unregistered integration event '{payload.GetType().FullName}'.");
            }

            var logical = messageFactory.Create(classStatusChanged, "ifx.registry", ClassStatusChangedV1.EventType, ClassStatusChangedV1.SchemaVersion, tenantId);
            dbContext.OutboxMessages.Add(RegistryOutboxStore.ToEntity(logical, classStatusChanged.ClassId.ToString("D"), DateTimeOffset.UtcNow.UtcTicks));
        }

        return Task.CompletedTask;
    }
}
