using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IFX.IntegrationTests.Runtime;

public sealed class OutboxDispatcherTests
{
    [Fact]
    public async Task Successful_send_preserves_logical_message_then_conditionally_completes()
    {
        var message = LogicalMessage();
        var store = new FakeStore(Lease(message, 1));
        var sender = new FakeSender();
        var telemetry = await DispatchAsync(store, sender, maximumAttempts: 3);

        sender.Messages.Should().ContainSingle().Which.Should().Be(message);
        store.Completed.Should().ContainSingle().Which.Message.Should().Be(message);
        store.Failures.Should().BeEmpty();
        telemetry.Snapshot(store.ModuleId).Should().Match<MessagingTelemetrySnapshot>(snapshot =>
            snapshot.DeliveryAttempts == 1 && snapshot.DeliverySuccesses == 1 &&
            snapshot.DeliveryFailures == 0 && snapshot.ConsecutiveFailures == 0);
    }

    [Fact]
    public async Task Failed_send_is_retried_without_mutating_logical_identity()
    {
        var message = LogicalMessage();
        var store = new FakeStore(Lease(message, 1));
        var sender = new FakeSender(new TimeoutException("transport unavailable"));
        var telemetry = await DispatchAsync(store, sender, maximumAttempts: 3);

        store.Failures.Should().ContainSingle();
        var failure = store.Failures.Single();
        failure.Lease.Message.Should().Be(message);
        failure.DeadLetter.Should().BeFalse();
        failure.ErrorCode.Should().Be(nameof(TimeoutException));
        telemetry.Snapshot(store.ModuleId).Should().Match<MessagingTelemetrySnapshot>(snapshot =>
            snapshot.DeliveryFailures == 1 && snapshot.ConsecutiveFailures == 1);
    }

    [Fact]
    public async Task Poison_message_reaches_dead_letter_at_bounded_attempt()
    {
        var store = new FakeStore(Lease(LogicalMessage(), 3));
        await DispatchAsync(store, new FakeSender(new InvalidOperationException("poison")), maximumAttempts: 3);

        store.Failures.Should().ContainSingle().Which.DeadLetter.Should().BeTrue();
    }

    [Fact]
    public async Task Crash_before_send_recovers_without_losing_the_logical_message()
    {
        var message = LogicalMessage();
        var store = new StatefulStore(message);

        await DispatchAsync(store, new FakeSender(new TimeoutException("crash before send")), maximumAttempts: 3);
        var recoveredSender = new FakeSender();
        await DispatchAsync(store, recoveredSender, maximumAttempts: 3);

        recoveredSender.Messages.Should().ContainSingle().Which.Envelope.EventId.Should().Be(message.Envelope.EventId);
        store.Delivered.Should().BeTrue();
    }

    [Fact]
    public async Task Crash_after_send_before_completion_redelivers_the_same_event_id()
    {
        var message = LogicalMessage();
        var store = new StatefulStore(message) { FailNextCompletionBeforeMark = true };
        var sender = new FakeSender();

        await DispatchAsync(store, sender, maximumAttempts: 3);
        await DispatchAsync(store, sender, maximumAttempts: 3);

        sender.Messages.Select(item => item.Envelope.EventId).Should().Equal(message.Envelope.EventId, message.Envelope.EventId);
        store.Delivered.Should().BeTrue();
    }

    [Fact]
    public async Task Completed_marker_prevents_redelivery_after_restart()
    {
        var message = LogicalMessage();
        var store = new StatefulStore(message);
        var firstSender = new FakeSender();

        await DispatchAsync(store, firstSender, maximumAttempts: 3);
        var restartedSender = new FakeSender();
        await DispatchAsync(store, restartedSender, maximumAttempts: 3);

        firstSender.Messages.Should().ContainSingle();
        restartedSender.Messages.Should().BeEmpty();
    }

    private static async Task<MessagingTelemetry> DispatchAsync(IModuleOutboxStore store, FakeSender sender, int maximumAttempts)
    {
        var services = new ServiceCollection().AddSingleton<IModuleOutboxStore>(store).BuildServiceProvider();
        var telemetry = new MessagingTelemetry();
        var dispatcher = new OutboxDispatcherHostedService(
            services.GetRequiredService<IServiceScopeFactory>(),
            sender,
            new OpenDrainSignal(),
            telemetry,
            Options.Create(new OutboxDispatcherOptions { MaximumAttempts = maximumAttempts }),
            "worker-test",
            NullLogger<OutboxDispatcherHostedService>.Instance);
        await dispatcher.DispatchOnceAsync(CancellationToken.None);
        await services.DisposeAsync();
        return telemetry;
    }

    private static OutboxLogicalMessage LogicalMessage()
    {
        var eventId = Guid.NewGuid();
        return new OutboxLogicalMessage(
            new EventEnvelope(eventId, "ifx.transaction.transaction-processed.v1", 1, DateTimeOffset.UtcNow, "ifx.transaction", EventEnvelope.TenantScope, Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid()),
            "{\"transactionId\":\"00000000-0000-0000-0000-000000000001\"}");
    }

    private static OutboxDispatchLease Lease(OutboxLogicalMessage message, int attempt) =>
        new(message, "transaction", "partition", 1, "worker-test", DateTimeOffset.UtcNow.AddMinutes(1), [1], attempt);

    private sealed class OpenDrainSignal : IRuntimeDrainSignal
    {
        public bool AcceptingNewWork => true;
        public CancellationToken DrainToken => CancellationToken.None;
    }

    private sealed class FakeSender(Exception? failure = null) : IIntegrationEventSender
    {
        public List<OutboxLogicalMessage> Messages { get; } = [];

        public Task SendAsync(OutboxLogicalMessage message, CancellationToken cancellationToken)
        {
            Messages.Add(message);
            return failure is null ? Task.CompletedTask : Task.FromException(failure);
        }
    }

    private sealed class FakeStore(params OutboxDispatchLease[] leases) : IModuleOutboxStore
    {
        public string ModuleId => "transaction";
        public List<OutboxDispatchLease> Completed { get; } = [];
        public List<(OutboxDispatchLease Lease, string ErrorCode, bool DeadLetter)> Failures { get; } = [];

        public Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<OutboxDispatchLease>>(leases);

        public Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken)
        {
            Completed.Add(lease);
            return Task.CompletedTask;
        }

        public Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken)
        {
            Failures.Add((lease, errorCode, deadLetter));
            return Task.CompletedTask;
        }

        public Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken) =>
            Task.FromResult(new OutboxBacklogSnapshot(ModuleId, 0, TimeSpan.Zero, 0, 0, null));

        public Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<OutboxDiagnosticRecord>>([]);

        public Task<bool> ReplayDeadLetterAsync(Guid eventId, DateTimeOffset requestedAt, CancellationToken cancellationToken) => Task.FromResult(false);
    }

    private sealed class StatefulStore(OutboxLogicalMessage message) : IModuleOutboxStore
    {
        private int _attempt;
        public string ModuleId => "transaction";
        public bool Delivered { get; private set; }
        public bool FailNextCompletionBeforeMark { get; set; }

        public Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken)
        {
            if (Delivered) return Task.FromResult<IReadOnlyList<OutboxDispatchLease>>([]);
            _attempt++;
            return Task.FromResult<IReadOnlyList<OutboxDispatchLease>>([Lease(message, _attempt)]);
        }

        public Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken)
        {
            if (FailNextCompletionBeforeMark)
            {
                FailNextCompletionBeforeMark = false;
                throw new TimeoutException("completion marker unavailable");
            }

            Delivered = true;
            return Task.CompletedTask;
        }

        public Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken) => Task.CompletedTask;

        public Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken) =>
            Task.FromResult(new OutboxBacklogSnapshot(ModuleId, Delivered ? 0 : 1, TimeSpan.Zero, Math.Max(0, _attempt - 1), 0, Delivered ? now : null));

        public Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<OutboxDiagnosticRecord>>([]);

        public Task<bool> ReplayDeadLetterAsync(Guid eventId, DateTimeOffset requestedAt, CancellationToken cancellationToken) => Task.FromResult(false);
    }
}
