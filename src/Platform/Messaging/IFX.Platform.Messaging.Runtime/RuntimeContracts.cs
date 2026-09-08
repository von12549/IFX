using IFX.Platform.Messaging.Contracts.Messaging;

namespace IFX.Platform.Messaging.Runtime;

public sealed record OutboxLogicalMessage(EventEnvelope Envelope, string Payload);

public sealed record OutboxDispatchLease(
    OutboxLogicalMessage Message,
    string ModuleId,
    string PartitionKey,
    long Sequence,
    string LeaseOwner,
    DateTimeOffset LeaseUntil,
    byte[] ConcurrencyToken,
    int AttemptCount);

public sealed record OutboxClaimRequest(string LeaseOwner, DateTimeOffset Now, DateTimeOffset LeaseUntil, int BatchSize);

public sealed record OutboxDiagnosticQuery(
    Guid? EventId = null,
    DateTimeOffset? From = null,
    DateTimeOffset? To = null,
    string? EventType = null,
    Guid? TenantId = null,
    int Limit = 100);

public sealed record OutboxDiagnosticRecord(
    Guid EventId,
    string ModuleId,
    string EventType,
    Guid? TenantId,
    DateTimeOffset OccurredAt,
    string State,
    int AttemptCount,
    DateTimeOffset? DeliveredAt,
    string? LastErrorCode);

public interface IModuleOutboxStore
{
    string ModuleId { get; }

    Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken);

    Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken);

    Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken);

    Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken);

    Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken);

    Task<bool> ReplayDeadLetterAsync(Guid eventId, DateTimeOffset requestedAt, CancellationToken cancellationToken);
}

public sealed record OutboxBacklogSnapshot(
    string ModuleId,
    long PendingCount,
    TimeSpan OldestPendingAge,
    long RetryCount,
    long DeadLetterCount,
    DateTimeOffset? LastSucceeded);

public interface IIntegrationEventSender
{
    Task SendAsync(OutboxLogicalMessage message, CancellationToken cancellationToken);
}

public interface IInboundIntegrationEventHandler
{
    bool CanHandle(string eventType, int schemaVersion);

    Task HandleAsync(OutboxLogicalMessage message, CancellationToken cancellationToken);
}

public interface IRuntimeDrainSignal
{
    bool AcceptingNewWork { get; }

    CancellationToken DrainToken { get; }
}
