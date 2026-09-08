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
        await DispatchAsync(store, sender, maximumAttempts: 3);

        sender.Messages.Should().ContainSingle().Which.Should().Be(message);
        store.Completed.Should().ContainSingle().Which.Message.Should().Be(message);
        store.Failures.Should().BeEmpty();
    }

    [Fact]
    public async Task Failed_send_is_retried_without_mutating_logical_identity()
    {
        var message = LogicalMessage();
        var store = new FakeStore(Lease(message, 1));
        var sender = new FakeSender(new TimeoutException("transport unavailable"));
        await DispatchAsync(store, sender, maximumAttempts: 3);

        store.Failures.Should().ContainSingle();
        var failure = store.Failures.Single();
        failure.Lease.Message.Should().Be(message);
        failure.DeadLetter.Should().BeFalse();
        failure.ErrorCode.Should().Be(nameof(TimeoutException));
    }

    [Fact]
    public async Task Poison_message_reaches_dead_letter_at_bounded_attempt()
    {
        var store = new FakeStore(Lease(LogicalMessage(), 3));
        await DispatchAsync(store, new FakeSender(new InvalidOperationException("poison")), maximumAttempts: 3);

        store.Failures.Should().ContainSingle().Which.DeadLetter.Should().BeTrue();
    }

    private static async Task DispatchAsync(FakeStore store, FakeSender sender, int maximumAttempts)
    {
        var services = new ServiceCollection().AddSingleton<IModuleOutboxStore>(store).BuildServiceProvider();
        var dispatcher = new OutboxDispatcherHostedService(
            services.GetRequiredService<IServiceScopeFactory>(),
            sender,
            new OpenDrainSignal(),
            Options.Create(new OutboxDispatcherOptions { MaximumAttempts = maximumAttempts }),
            "worker-test",
            NullLogger<OutboxDispatcherHostedService>.Instance);
        await dispatcher.DispatchOnceAsync(CancellationToken.None);
        await services.DisposeAsync();
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
}
