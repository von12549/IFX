using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.Runtime;

public sealed class StartupDependencyMonitor(
    HealthCheckService healthChecks,
    RuntimeLifecycle lifecycle,
    RuntimeProfile runtimeProfile,
    HealthSnapshotStore snapshotStore,
    ILogger<StartupDependencyMonitor> logger,
    IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        lifecycle.MarkAliveNotReady("G04-READY-CHECK-PENDING");
        var interval = TimeSpan.FromSeconds(Math.Max(1, configuration.GetValue("Runtime:DependencyPollSeconds", 10)));
        var timeout = TimeSpan.FromSeconds(Math.Max(1, configuration.GetValue("Runtime:DependencyTimeoutSeconds", 5)));

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                timeoutSource.CancelAfter(timeout);
                var report = await healthChecks.CheckHealthAsync(
                    registration => registration.Tags.Contains("readiness-critical") &&
                        registration.Tags.Contains(runtimeProfile.RoleName),
                    timeoutSource.Token);
                snapshotStore.Update(report, DateTimeOffset.UtcNow);
                if (report.Status == HealthStatus.Healthy)
                {
                    lifecycle.MarkReady();
                }
                else
                {
                    lifecycle.MarkAliveNotReady("G04-READY-DEPENDENCY-UNAVAILABLE");
                }
            }
            catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
            {
                lifecycle.MarkAliveNotReady("G04-READY-DEPENDENCY-TIMEOUT");
                snapshotStore.RecordFailure("G04-READY-DEPENDENCY-TIMEOUT", DateTimeOffset.UtcNow);
            }
            catch (Exception exception)
            {
                lifecycle.MarkAliveNotReady("G04-READY-DEPENDENCY-CHECK-FAILED");
                snapshotStore.RecordFailure("G04-READY-DEPENDENCY-CHECK-FAILED", DateTimeOffset.UtcNow);
                logger.LogWarning(exception, "Runtime dependency verification failed with {ReasonCode}", lifecycle.Snapshot.ReasonCode);
            }

            await Task.Delay(interval, stoppingToken);
        }
    }
}
