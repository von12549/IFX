using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Composition;

public enum MessagingHealthSeverity { Healthy, Warning, Critical }

public sealed record MessagingModuleHealth(
    string ModuleId,
    MessagingHealthSeverity Severity,
    string ReasonCode,
    long PendingCount,
    double OldestPendingAgeSeconds,
    long RetryCount,
    long DeadLetterCount,
    long LeasedCount,
    long ExpiredLeaseCount,
    DateTimeOffset? LastSucceeded,
    double ProcessingRatePerSecond);

public sealed class MessagingHealthThresholds
{
    public TimeSpan WarningAge { get; set; } = TimeSpan.FromMinutes(2);
    public TimeSpan CriticalAge { get; set; } = TimeSpan.FromMinutes(10);
    public long WarningCount { get; set; } = 500;
    public long CriticalCount { get; set; } = 5000;
    public long WarningDeadLetters { get; set; } = 1;
    public long CriticalDeadLetters { get; set; } = 10;
    public double CriticalStorageUtilization { get; set; } = 0.85;
    public TimeSpan RetryAfter { get; set; } = TimeSpan.FromSeconds(30);

    internal BacklogThreshold ToRuntimeThreshold()
    {
        var threshold = new BacklogThreshold(
            WarningAge, CriticalAge, WarningCount, CriticalCount,
            WarningDeadLetters, CriticalDeadLetters, CriticalStorageUtilization, RetryAfter);
        _ = MessageBackpressurePolicy.Evaluate(
            new MessageBacklogObservation("validation", "integration", 0, TimeSpan.Zero, 0, 0, null, 0, 0, 0, 0),
            threshold,
            DateTimeOffset.UnixEpoch);
        return threshold;
    }
}

public interface IMessagingHealthProbe
{
    Task<IReadOnlyList<MessagingModuleHealth>> CheckAsync(CancellationToken cancellationToken);
}

internal sealed class RuntimeMessagingHealthProbe(
    IServiceScopeFactory scopeFactory,
    MessagingTelemetry telemetry,
    MessagingHealthThresholds thresholds) : IMessagingHealthProbe
{
    public async Task<IReadOnlyList<MessagingModuleHealth>> CheckAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var now = DateTimeOffset.UtcNow;
        var threshold = thresholds.ToRuntimeThreshold();
        var results = new List<MessagingModuleHealth>();
        foreach (var store in scope.ServiceProvider.GetServices<IModuleOutboxStore>().OrderBy(item => item.ModuleId, StringComparer.Ordinal))
        {
            var backlog = await store.ObserveAsync(now, cancellationToken);
            telemetry.RecordBacklog(backlog);
            var rate = telemetry.Snapshot(store.ModuleId).ProcessingRatePerSecond;
            var evaluation = MessageBackpressurePolicy.Evaluate(
                new MessageBacklogObservation(
                    store.ModuleId,
                    "integration",
                    backlog.PendingCount,
                    backlog.OldestPendingAge,
                    backlog.RetryCount,
                    backlog.DeadLetterCount,
                    backlog.LastSucceeded,
                    rate,
                    StorageUtilization: 0,
                    ExpiredLeaseCount: backlog.ExpiredLeaseCount,
                    DuplicateRate: 0),
                threshold,
                now);
            results.Add(new MessagingModuleHealth(
                store.ModuleId,
                evaluation.Severity switch
                {
                    BacklogSeverity.Warning => MessagingHealthSeverity.Warning,
                    BacklogSeverity.Critical => MessagingHealthSeverity.Critical,
                    _ => MessagingHealthSeverity.Healthy
                },
                evaluation.ReasonCode,
                backlog.PendingCount,
                backlog.OldestPendingAge.TotalSeconds,
                backlog.RetryCount,
                backlog.DeadLetterCount,
                backlog.LeasedCount,
                backlog.ExpiredLeaseCount,
                backlog.LastSucceeded,
                rate));
        }

        return results;
    }
}
