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
            thresholds.WarningSilence = TimeSpan.FromMinutes(30);
            thresholds.CriticalSilence = TimeSpan.FromHours(1);
        });
        services.AddSingleton<IModuleOutboxStore>(new HealthStore(
            new OutboxBacklogSnapshot("transaction", pending, TimeSpan.FromMinutes(pending), 2, deadLetters, null, 1, 1)));
        await using var provider = services.BuildServiceProvider();

        var result = (await provider.GetRequiredService<IMessagingHealthProbe>().CheckAsync(CancellationToken.None)).Single();

        result.Severity.Should().Be(expectedSeverity);
        result.ReasonCode.Should().Be(expectedReason);
        result.LeasedCount.Should().Be(1);
        result.ExpiredLeaseCount.Should().Be(1);
        result.DispatcherSilenceSeconds.Should().Be(TimeSpan.FromMinutes(pending).TotalSeconds);
    }

    [Fact]
    public void Invalid_threshold_order_is_rejected_during_registration()
    {
        var services = new ServiceCollection();

        var act = () => services.AddReliableMessaging("test", false, thresholds =>
            thresholds.WarningCount = thresholds.CriticalCount);

        act.Should().Throw<InvalidOperationException>().WithMessage("G04-BACKPRESSURE-THRESHOLD-INVALID");
    }

    [Fact]
    public async Task Probe_surfaces_consecutive_delivery_failures()
    {
        var services = new ServiceCollection();
        services.AddReliableMessaging("test", dispatcherEnabled: false);
        services.AddSingleton<IModuleOutboxStore>(new HealthStore(
            new OutboxBacklogSnapshot("transaction", 0, TimeSpan.Zero, 0, 0, DateTimeOffset.UtcNow)));
        await using var provider = services.BuildServiceProvider();
        var telemetry = provider.GetRequiredService<MessagingTelemetry>();
        telemetry.RecordFailure("transaction", false);
        telemetry.RecordFailure("transaction", false);
        telemetry.RecordFailure("transaction", false);

        var result = (await provider.GetRequiredService<IMessagingHealthProbe>().CheckAsync(CancellationToken.None)).Single();

        result.Severity.Should().Be(MessagingHealthSeverity.Warning);
        result.ReasonCode.Should().Be("G04-DELIVERY-FAILURES-WARNING");
        result.ConsecutiveFailures.Should().Be(3);
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
