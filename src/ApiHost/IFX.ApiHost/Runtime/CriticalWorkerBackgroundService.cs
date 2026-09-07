namespace IFX.ApiHost.Runtime;

/// <summary>
/// Base for critical E3 worker loops. An unhandled loop failure changes readiness and requests
/// non-zero process termination; per-message failures must be handled by the durable retry state machine.
/// </summary>
public abstract class CriticalWorkerBackgroundService(
    RuntimeLifecycle lifecycle,
    IHostApplicationLifetime applicationLifetime,
    ILogger logger) : BackgroundService
{
    protected sealed override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await RunCriticalLoopAsync(stoppingToken);
            if (!stoppingToken.IsCancellationRequested)
            {
                throw new InvalidOperationException("Critical worker loop returned before shutdown.");
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            lifecycle.MarkAliveNotReady("G04-WORKER-CRITICAL-LOOP-FAILED");
            Environment.ExitCode = 1;
            logger.LogCritical(exception, "Critical worker loop failed; terminating with {ReasonCode}", lifecycle.Snapshot.ReasonCode);
            applicationLifetime.StopApplication();
        }
    }

    protected abstract Task RunCriticalLoopAsync(CancellationToken stoppingToken);
}
