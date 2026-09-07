using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.Runtime;

public sealed class StartupDependencyMonitor(
    HealthCheckService healthChecks,
    RuntimeLifecycle lifecycle,
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
                    registration => registration.Tags.Contains("readiness-critical"),
                    timeoutSource.Token);
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
            }
            catch (Exception exception)
            {
                lifecycle.MarkAliveNotReady("G04-READY-DEPENDENCY-CHECK-FAILED");
                logger.LogWarning(exception, "Runtime dependency verification failed with {ReasonCode}", lifecycle.Snapshot.ReasonCode);
            }

            await Task.Delay(interval, stoppingToken);
        }
    }
}
