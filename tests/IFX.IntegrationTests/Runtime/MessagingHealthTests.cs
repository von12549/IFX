using IFX.Platform.Messaging.Composition;
using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.IntegrationTests.Runtime;

public sealed class MessagingHealthTests
{
    [Theory]
    [InlineData(0, 0, MessagingHealthSeverity.Healthy, "G04-BACKLOG-HEALTHY")]
    [InlineData(5, 1, MessagingHealthSeverity.Warning, "G04-BACKLOG-WARNING")]
    [InlineData(20, 10, MessagingHealthSeverity.Critical, "G04-BACKLOG-CRITICAL")]
    public async Task Probe_maps_backlog_to_operational_severity(
        long pending,
        long deadLetters,
        MessagingHealthSeverity expectedSeverity,
        string expectedReason)
    {
        var services = new ServiceCollection();
        services.AddReliableMessaging("test", dispatcherEnabled: false, thresholds =>
        {
            thresholds.WarningCount = 5;
            thresholds.CriticalCount = 20;
            thresholds.WarningDeadLetters = 1;
            thresholds.CriticalDeadLetters = 10;
        });
        services.AddSingleton<IModuleOutboxStore>(new HealthStore(
            new OutboxBacklogSnapshot("transaction", pending, TimeSpan.FromMinutes(pending), 2, deadLetters, null, 1, 1)));
        await using var provider = services.BuildServiceProvider();

        var result = (await provider.GetRequiredService<IMessagingHealthProbe>().CheckAsync(CancellationToken.None)).Single();

        result.Severity.Should().Be(expectedSeverity);
        result.ReasonCode.Should().Be(expectedReason);
        result.LeasedCount.Should().Be(1);
        result.ExpiredLeaseCount.Should().Be(1);
    }

    [Fact]
    public void Invalid_threshold_order_is_rejected_during_registration()
    {
        var services = new ServiceCollection();

        var act = () => services.AddReliableMessaging("test", false, thresholds =>
            thresholds.WarningCount = thresholds.CriticalCount);

        act.Should().Throw<InvalidOperationException>().WithMessage("G04-BACKPRESSURE-THRESHOLD-INVALID");
    }

    private sealed class HealthStore(OutboxBacklogSnapshot snapshot) : IModuleOutboxStore
    {
        public string ModuleId => snapshot.ModuleId;
        public Task<IReadOnlyList<OutboxDispatchLease>> ClaimAsync(OutboxClaimRequest request, CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<OutboxDispatchLease>>([]);
        public Task CompleteAsync(OutboxDispatchLease lease, DateTimeOffset deliveredAt, CancellationToken cancellationToken) => Task.CompletedTask;
        public Task FailAsync(OutboxDispatchLease lease, DateTimeOffset nextAttemptAt, string errorCode, bool deadLetter, CancellationToken cancellationToken) => Task.CompletedTask;
        public Task<OutboxBacklogSnapshot> ObserveAsync(DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult(snapshot);
        public Task<IReadOnlyList<OutboxDiagnosticRecord>> QueryAsync(OutboxDiagnosticQuery query, CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<OutboxDiagnosticRecord>>([]);
        public Task<bool> ReplayDeadLetterAsync(Guid eventId, DateTimeOffset requestedAt, CancellationToken cancellationToken) => Task.FromResult(false);
    }
}
