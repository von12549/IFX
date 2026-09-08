using IFX.Platform.Messaging.Composition;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace IFX.ApiHost.HealthChecks;

public sealed class MessagingOutboxHealthCheck(IMessagingHealthProbe probe) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var modules = await probe.CheckAsync(cancellationToken);
            var data = modules.ToDictionary(
                item => item.ModuleId,
                item => (object)new
                {
                    severity = item.Severity.ToString(),
                    reason = item.ReasonCode,
                    item.PendingCount,
                    item.OldestPendingAgeSeconds,
                    item.RetryCount,
                    item.DeadLetterCount,
                    item.LeasedCount,
                    item.ExpiredLeaseCount,
                    item.LastSucceeded,
                    item.ProcessingRatePerSecond
                },
                StringComparer.Ordinal);
            if (modules.Any(item => item.Severity == MessagingHealthSeverity.Critical))
                return HealthCheckResult.Unhealthy("One or more module Outboxes are critical.", data: data);
            if (modules.Any(item => item.Severity == MessagingHealthSeverity.Warning))
                return HealthCheckResult.Degraded("One or more module Outboxes require attention.", data: data);
            return HealthCheckResult.Healthy("Module Outboxes are healthy.", data);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            return HealthCheckResult.Unhealthy("Module Outbox health could not be evaluated.");
        }
    }
}
