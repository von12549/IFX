using IFX.Platform.Messaging.Composition;
using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Runtime;

public sealed class MessagingOperationsTests
{
    [Fact]
    public async Task Diagnostics_require_permission_and_merge_outbox_and_inbox_without_payloads()
    {
        var eventId = Guid.NewGuid();
        await using var provider = BuildProvider(new OperationsOutboxStore(eventId), new OperationsInboxStore(eventId));
        var operations = provider.GetRequiredService<IMessagingOperations>();

        var snapshot = await operations.QueryAsync(new MessagingDiagnosticQuery(EventId: eventId), "operator", CancellationToken.None);

        snapshot.Outbox.Should().ContainSingle().Which.EventId.Should().Be(eventId);
        snapshot.Inbox.Should().ContainSingle().Which.EventId.Should().Be(eventId);
        Func<Task> denied = () => operations.QueryAsync(new MessagingDiagnosticQuery(), "denied", CancellationToken.None);
        await denied.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Replay_dry_run_and_execution_preserve_event_id_and_are_audited()
    {
        var eventId = Guid.NewGuid();
        var store = new OperationsOutboxStore(eventId);
        var audit = new RecordingAuditSink();
        await using var provider = BuildProvider(store, new OperationsInboxStore(eventId), audit);
        var operations = provider.GetRequiredService<IMessagingOperations>();
        var request = new MessagingReplayRequest(
            Guid.NewGuid(), store.ModuleId, [eventId], "operator", "approved recovery", "holdings-1");

        var preview = await operations.ReplayAsync(request, CancellationToken.None);
        var execution = await operations.ReplayAsync(request with { DryRun = false }, CancellationToken.None);

        preview.Items.Should().ContainSingle().Which.ReasonCode.Should().Be("DRY-RUN-ELIGIBLE");
        store.ReplayedEventIds.Should().ContainSingle().Which.Should().Be(eventId);
        execution.Items.Should().ContainSingle().Which.Replayed.Should().BeTrue();
        audit.Records.Should().HaveCount(2).And.OnlyContain(item => item.EventIds.Single() == eventId && item.Authorized);
    }

    [Fact]
    public async Task Replay_rejects_incompatible_handler_and_audits_denied_requests()
    {
        var eventId = Guid.NewGuid();
        var store = new OperationsOutboxStore(eventId);
        var audit = new RecordingAuditSink();
        await using var provider = BuildProvider(store, new OperationsInboxStore(eventId), audit);
        var operations = provider.GetRequiredService<IMessagingOperations>();

        var incompatible = await operations.ReplayAsync(
            new MessagingReplayRequest(Guid.NewGuid(), store.ModuleId, [eventId], "operator", "test", "old-handler", false),
            CancellationToken.None);
        Func<Task> denied = () => operations.ReplayAsync(
            new MessagingReplayRequest(Guid.NewGuid(), store.ModuleId, [eventId], "denied", "test", "holdings-1", false),
            CancellationToken.None);

        incompatible.Items.Should().ContainSingle().Which.ReasonCode.Should().Be("HANDLER-VERSION-INCOMPATIBLE");
        await denied.Should().ThrowAsync<UnauthorizedAccessException>();
        store.ReplayedEventIds.Should().BeEmpty();
        audit.Records.Should().Contain(item => !item.Authorized && item.ActorId == "denied");
    }

    private static ServiceProvider BuildProvider(
        OperationsOutboxStore outbox,
        OperationsInboxStore inbox,
        RecordingAuditSink? audit = null)
    {
        var services = new ServiceCollection();
        services.AddMessagingOperations<AllowAuthorizer, VersionGuard, RecordingAuditSink>();
        services.AddSingleton<IModuleOutboxStore>(outbox);
        services.AddSingleton<IModuleInboxDiagnosticStore>(inbox);
        if (audit is not null) services.AddSingleton<IMessagingOperationsAuditSink>(audit);
        return services.BuildServiceProvider();
    }

    private sealed class AllowAuthorizer : IMessagingOperationsAuthorizer
    {
        public Task<bool> IsAuthorizedAsync(string actorId, string action, string moduleId, CancellationToken cancellationToken) =>
            Task.FromResult(actorId != "denied");
    }

    private sealed class VersionGuard : IMessagingReplayGuard
    {
        public Task<string?> ValidateAsync(MessagingOutboxDiagnostic message, string targetHandlerVersion, CancellationToken cancellationToken) =>
            Task.FromResult<string?>(targetHandlerVersion == "holdings-1" ? null : "HANDLER-VERSION-INCOMPATIBLE");
    }

    private sealed class RecordingAuditSink : IMessagingOperationsAuditSink
    {
        public List<MessagingOperationsAuditRecord> Records { get; } = [];
        public Task WriteAsync(MessagingOperationsAuditRecord record, CancellationToken cancellationToken)
        {
            Records.Add(record);
            return Task.CompletedTask;
        }
    }

    private sealed class OperationsOutboxStore(Guid eventId) : IModuleOutboxStore
    {
        public string ModuleId => "transaction";
        public List<Guid> ReplayedEventIds { get; } = [];
        public Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<OutboxDispatchLease>>([]);
        public Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken) => Task.CompletedTask;
        public Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken) => Task.CompletedTask;
        public Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult(new OutboxBacklogSnapshot(ModuleId, 0, TimeSpan.Zero, 0, 1, null));
        public Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<OutboxDiagnosticRecord>>(query.EventId is null || query.EventId == eventId
                ? [new OutboxDiagnosticRecord(eventId, ModuleId, "ifx.transaction.transaction-processed.v1", 1, Guid.NewGuid(), DateTimeOffset.UtcNow, "DeadLettered", 3, null, "TimeoutException")]
                : []);
        public Task<bool> ReplayDeadLetterAsync(Guid requestedEventId, DateTimeOffset requestedAt, CancellationToken cancellationToken)
        {
            if (requestedEventId != eventId) return Task.FromResult(false);
            ReplayedEventIds.Add(requestedEventId);
            return Task.FromResult(true);
        }
    }

    private sealed class OperationsInboxStore(Guid eventId) : IModuleInboxDiagnosticStore
    {
        public string ModuleId => "holdings";
        public Task<IReadOnlyList<InboxDiagnosticRecord>> QueryAsync(InboxDiagnosticQuery query, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<InboxDiagnosticRecord>>(query.EventId is null || query.EventId == eventId
                ? [new InboxDiagnosticRecord(eventId, ModuleId, "holdings.transaction-processed.v1", "ifx.transaction.transaction-processed.v1", Guid.NewGuid(), DateTimeOffset.UtcNow)]
                : []);
    }
}
