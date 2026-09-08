using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Composition;

public sealed record MessagingDiagnosticQuery(
    Guid? EventId = null,
    DateTimeOffset? From = null,
    DateTimeOffset? To = null,
    string? EventType = null,
    Guid? TenantId = null,
    int Limit = 100);

public sealed record MessagingDiagnosticSnapshot(
    IReadOnlyList<MessagingOutboxDiagnostic> Outbox,
    IReadOnlyList<MessagingInboxDiagnostic> Inbox);

public sealed record MessagingOutboxDiagnostic(
    Guid EventId,
    string ModuleId,
    string EventType,
    int SchemaVersion,
    Guid? TenantId,
    DateTimeOffset OccurredAt,
    string State,
    int AttemptCount,
    DateTimeOffset? DeliveredAt,
    string? LastErrorCode);

public sealed record MessagingInboxDiagnostic(
    Guid EventId,
    string ModuleId,
    string ConsumerId,
    string EventType,
    Guid TenantId,
    DateTimeOffset CompletedAt);

public sealed record MessagingReplayRequest(
    Guid RequestId,
    string ModuleId,
    IReadOnlyCollection<Guid> EventIds,
    string ActorId,
    string Reason,
    string TargetHandlerVersion,
    bool DryRun = true);

public sealed record MessagingReplayItem(Guid EventId, bool Eligible, bool Replayed, string ReasonCode);

public sealed record MessagingReplayResult(Guid RequestId, bool DryRun, IReadOnlyList<MessagingReplayItem> Items);

public sealed record MessagingOperationsAuditRecord(
    Guid RequestId,
    string Action,
    string ModuleId,
    IReadOnlyCollection<Guid> EventIds,
    string ActorId,
    string Reason,
    string TargetHandlerVersion,
    bool DryRun,
    bool Authorized,
    DateTimeOffset RecordedAt);

public interface IMessagingOperations
{
    Task<MessagingDiagnosticSnapshot> QueryAsync(MessagingDiagnosticQuery query, string actorId, CancellationToken cancellationToken);

    Task<MessagingReplayResult> ReplayAsync(MessagingReplayRequest request, CancellationToken cancellationToken);
}

public interface IMessagingOperationsAuthorizer
{
    Task<bool> IsAuthorizedAsync(string actorId, string action, string moduleId, CancellationToken cancellationToken);
}

public interface IMessagingReplayGuard
{
    Task<string?> ValidateAsync(MessagingOutboxDiagnostic message, string targetHandlerVersion, CancellationToken cancellationToken);
}

public interface IMessagingOperationsAuditSink
{
    Task WriteAsync(MessagingOperationsAuditRecord record, CancellationToken cancellationToken);
}

public static class MessagingOperationsInstaller
{
    public static IServiceCollection AddMessagingOperations<TAuthorizer, TReplayGuard, TAuditSink>(this IServiceCollection services)
        where TAuthorizer : class, IMessagingOperationsAuthorizer
        where TReplayGuard : class, IMessagingReplayGuard
        where TAuditSink : class, IMessagingOperationsAuditSink
    {
        services.AddScoped<IMessagingOperationsAuthorizer, TAuthorizer>();
        services.AddScoped<IMessagingReplayGuard, TReplayGuard>();
        services.AddScoped<IMessagingOperationsAuditSink, TAuditSink>();
        services.AddScoped<IMessagingOperations, RuntimeMessagingOperations>();
        return services;
    }
}

internal sealed class RuntimeMessagingOperations(
    IServiceScopeFactory scopeFactory,
    IMessagingOperationsAuthorizer authorizer,
    IMessagingReplayGuard replayGuard,
    IMessagingOperationsAuditSink auditSink) : IMessagingOperations
{
    private const int MaximumBatchSize = 100;

    public async Task<MessagingDiagnosticSnapshot> QueryAsync(
        MessagingDiagnosticQuery query,
        string actorId,
        CancellationToken cancellationToken)
    {
        ValidateActor(actorId);
        if (!await authorizer.IsAuthorizedAsync(actorId, "messaging.diagnostics.read", "*", cancellationToken))
            throw new UnauthorizedAccessException("Messaging diagnostics permission is required.");

        await using var scope = scopeFactory.CreateAsyncScope();
        var limit = Math.Clamp(query.Limit, 1, 500);
        var outboxQuery = new OutboxDiagnosticQuery(query.EventId, query.From, query.To, query.EventType, query.TenantId, limit);
        var inboxQuery = new InboxDiagnosticQuery(query.EventId, query.From, query.To, query.EventType, query.TenantId, limit);
        var outbox = new List<OutboxDiagnosticRecord>();
        foreach (var store in scope.ServiceProvider.GetServices<IModuleOutboxStore>())
            outbox.AddRange(await store.QueryAsync(outboxQuery, cancellationToken));
        var inbox = new List<InboxDiagnosticRecord>();
        foreach (var store in scope.ServiceProvider.GetServices<IModuleInboxDiagnosticStore>())
            inbox.AddRange(await store.QueryAsync(inboxQuery, cancellationToken));
        return new MessagingDiagnosticSnapshot(
            outbox.OrderByDescending(item => item.OccurredAt).Take(limit).Select(ToPublic).ToArray(),
            inbox.OrderByDescending(item => item.CompletedAt).Take(limit).Select(ToPublic).ToArray());
    }

    public async Task<MessagingReplayResult> ReplayAsync(MessagingReplayRequest request, CancellationToken cancellationToken)
    {
        ValidateReplayRequest(request);
        var authorized = await authorizer.IsAuthorizedAsync(
            request.ActorId, request.DryRun ? "messaging.replay.preview" : "messaging.replay.execute", request.ModuleId, cancellationToken);
        await auditSink.WriteAsync(new MessagingOperationsAuditRecord(
            request.RequestId, "dead-letter-replay", request.ModuleId, request.EventIds, request.ActorId,
            request.Reason, request.TargetHandlerVersion, request.DryRun, authorized, DateTimeOffset.UtcNow), cancellationToken);
        if (!authorized) throw new UnauthorizedAccessException("Messaging replay permission is required.");

        await using var scope = scopeFactory.CreateAsyncScope();
        var store = scope.ServiceProvider.GetServices<IModuleOutboxStore>()
            .SingleOrDefault(candidate => string.Equals(candidate.ModuleId, request.ModuleId, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException("The requested module Outbox is not registered.");
        var results = new List<MessagingReplayItem>(request.EventIds.Count);
        foreach (var eventId in request.EventIds.Distinct())
        {
            var diagnostic = (await store.QueryAsync(new OutboxDiagnosticQuery(EventId: eventId, Limit: 1), cancellationToken)).SingleOrDefault();
            if (diagnostic is null)
            {
                results.Add(new MessagingReplayItem(eventId, false, false, "MESSAGE-NOT-FOUND"));
                continue;
            }
            if (!string.Equals(diagnostic.State, "DeadLettered", StringComparison.Ordinal))
            {
                results.Add(new MessagingReplayItem(eventId, false, false, "MESSAGE-NOT-DEAD-LETTERED"));
                continue;
            }

            var rejection = await replayGuard.ValidateAsync(ToPublic(diagnostic), request.TargetHandlerVersion, cancellationToken);
            if (rejection is not null)
            {
                results.Add(new MessagingReplayItem(eventId, false, false, rejection));
                continue;
            }

            var replayed = !request.DryRun && await store.ReplayDeadLetterAsync(eventId, DateTimeOffset.UtcNow, cancellationToken);
            results.Add(new MessagingReplayItem(eventId, true, replayed, request.DryRun ? "DRY-RUN-ELIGIBLE" : replayed ? "REPLAY-QUEUED" : "REPLAY-RACE-LOST"));
        }

        return new MessagingReplayResult(request.RequestId, request.DryRun, results);
    }

    private static void ValidateActor(string actorId)
    {
        ValidateBoundedText(actorId, 128, "Actor id");
    }

    private static void ValidateReplayRequest(MessagingReplayRequest request)
    {
        if (request.RequestId == Guid.Empty) throw new ArgumentException("Request id is required.", nameof(request));
        ValidateBoundedText(request.ModuleId, 64, "Module id");
        ValidateBoundedText(request.Reason, 128, "Reason/change reference");
        ValidateBoundedText(request.TargetHandlerVersion, 64, "Target handler version");
        ValidateActor(request.ActorId);
        if (request.EventIds.Count is < 1 or > MaximumBatchSize || request.EventIds.Any(id => id == Guid.Empty))
            throw new ArgumentException($"Replay must contain 1-{MaximumBatchSize} non-empty event ids.", nameof(request));
    }

    private static void ValidateBoundedText(string value, int maximumLength, string name)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maximumLength || value.Any(char.IsControl))
            throw new ArgumentException($"{name} is missing or invalid.");
    }

    private static MessagingOutboxDiagnostic ToPublic(OutboxDiagnosticRecord item) => new(
        item.EventId, item.ModuleId, item.EventType, item.SchemaVersion, item.TenantId, item.OccurredAt,
        item.State, item.AttemptCount, item.DeliveredAt, item.LastErrorCode);

    private static MessagingInboxDiagnostic ToPublic(InboxDiagnosticRecord item) => new(
        item.EventId, item.ModuleId, item.ConsumerId, item.EventType, item.TenantId, item.CompletedAt);
}
