using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Messaging;

public sealed class RegistryOutboxStore(RegistryDbContext dbContext) : IModuleOutboxStore
{
    public string ModuleId => "registry";

    public async Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var candidates = await dbContext.OutboxMessages.FromSqlInterpolated($$"""
            SELECT TOP ({{request.BatchSize}}) [candidate].*
            FROM [registry].[OutboxMessages] AS [candidate] WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE [candidate].[State] = N'Pending'
              AND [candidate].[NextAttemptAt] <= {{request.Now}}
              AND ([candidate].[LeaseUntil] IS NULL OR [candidate].[LeaseUntil] < {{request.Now}})
              AND NOT EXISTS (
                  SELECT 1 FROM [registry].[OutboxMessages] AS [earlier]
                  WHERE [earlier].[PartitionKey] = [candidate].[PartitionKey]
                    AND [earlier].[Sequence] < [candidate].[Sequence]
                    AND [earlier].[State] = N'Pending')
            ORDER BY [candidate].[Sequence]
            """).ToListAsync(cancellationToken);
        foreach (var message in candidates)
        {
            message.LeaseOwner = request.LeaseOwner;
            message.LeaseUntil = request.LeaseUntil;
            message.AttemptCount++;
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return candidates.Select(ToLease).ToArray();
    }

    public async Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken)
    {
        var message = await OwnedLeaseAsync(lease, cancellationToken);
        message.State = OutboxStates.Delivered;
        message.DeliveredAt = deliveredAt;
        message.LeaseOwner = null;
        message.LeaseUntil = null;
        message.LastErrorCode = null;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken)
    {
        var message = await OwnedLeaseAsync(lease, cancellationToken);
        message.State = deadLetter ? OutboxStates.DeadLettered : OutboxStates.Pending;
        message.NextAttemptAt = nextAttemptAt;
        message.LeaseOwner = null;
        message.LeaseUntil = null;
        message.LastErrorCode = errorCode;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken)
    {
        var pending = dbContext.OutboxMessages.Where(message => message.State == OutboxStates.Pending);
        var oldest = await pending.MinAsync(message => (DateTimeOffset?)message.CreatedAt, cancellationToken);
        return new OutboxBacklogSnapshot(
            ModuleId,
            await pending.LongCountAsync(cancellationToken),
            oldest is null ? TimeSpan.Zero : now - oldest.Value,
            await pending.LongCountAsync(message => message.AttemptCount > 1, cancellationToken),
            await dbContext.OutboxMessages.LongCountAsync(message => message.State == OutboxStates.DeadLettered, cancellationToken),
            await dbContext.OutboxMessages.Where(message => message.DeliveredAt != null).MaxAsync(message => message.DeliveredAt, cancellationToken));
    }

    public async Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken)
    {
        var messages = dbContext.OutboxMessages.AsNoTracking();
        if (query.EventId is { } eventId) messages = messages.Where(message => message.EventId == eventId);
        if (query.From is { } from) messages = messages.Where(message => message.OccurredAt >= from);
        if (query.To is { } to) messages = messages.Where(message => message.OccurredAt <= to);
        if (!string.IsNullOrWhiteSpace(query.EventType)) messages = messages.Where(message => message.EventType == query.EventType);
        if (query.TenantId is { } tenantId) messages = messages.Where(message => message.TenantId == tenantId);
        var limit = Math.Clamp(query.Limit, 1, 500);
        return await messages.OrderByDescending(message => message.OccurredAt).Take(limit)
            .Select(message => new OutboxDiagnosticRecord(message.EventId, ModuleId, message.EventType, message.TenantId, message.OccurredAt, message.State, message.AttemptCount, message.DeliveredAt, message.LastErrorCode))
            .ToListAsync(cancellationToken);
    }

    public async Task<bool> ReplayDeadLetterAsync(Guid eventId, DateTimeOffset requestedAt, CancellationToken cancellationToken)
    {
        var message = await dbContext.OutboxMessages.SingleOrDefaultAsync(candidate => candidate.EventId == eventId && candidate.State == OutboxStates.DeadLettered, cancellationToken);
        if (message is null) return false;
        message.State = OutboxStates.Pending;
        message.NextAttemptAt = requestedAt;
        message.LeaseOwner = null;
        message.LeaseUntil = null;
        message.LastErrorCode = "ReplayRequested";
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    internal static RegistryOutboxMessage ToEntity(OutboxLogicalMessage logical, string partitionKey, long sequence) => new()
    {
        EventId = logical.Envelope.EventId, EnvelopeVersion = logical.Envelope.EnvelopeVersion, EventType = logical.Envelope.EventType,
        SchemaVersion = logical.Envelope.SchemaVersion, OccurredAt = logical.Envelope.OccurredAt, Producer = logical.Envelope.Producer,
        Scope = logical.Envelope.Scope, TenantId = logical.Envelope.TenantId, CorrelationId = logical.Envelope.CorrelationId,
        CausationId = logical.Envelope.CausationId, ContentType = logical.Envelope.ContentType, TraceParent = logical.Envelope.TraceParent,
        TraceState = logical.Envelope.TraceState, Provenance = logical.Envelope.Provenance, Payload = logical.Payload,
        PartitionKey = partitionKey, Sequence = sequence, NextAttemptAt = DateTimeOffset.UtcNow, CreatedAt = DateTimeOffset.UtcNow
    };

    private static OutboxDispatchLease ToLease(RegistryOutboxMessage message) => new(ToLogical(message), "registry", message.PartitionKey, message.Sequence, message.LeaseOwner!, message.LeaseUntil!.Value, message.ConcurrencyToken, message.AttemptCount);

    private static OutboxLogicalMessage ToLogical(RegistryOutboxMessage message) => new(
        new EventEnvelope(message.EventId, message.EventType, message.SchemaVersion, message.OccurredAt, message.Producer, message.Scope, message.TenantId, message.CorrelationId, message.CausationId, message.ContentType, message.TraceParent, message.TraceState, message.Provenance, message.EnvelopeVersion),
        message.Payload);

    private async Task<RegistryOutboxMessage> OwnedLeaseAsync(OutboxDispatchLease lease, CancellationToken cancellationToken)
    {
        var message = await dbContext.OutboxMessages.SingleAsync(candidate => candidate.EventId == lease.Message.Envelope.EventId && candidate.LeaseOwner == lease.LeaseOwner && candidate.State == OutboxStates.Pending, cancellationToken);
        if (!message.ConcurrencyToken.SequenceEqual(lease.ConcurrencyToken)) throw new DbUpdateConcurrencyException("The Registry Outbox lease is stale.");
        return message;
    }
}
