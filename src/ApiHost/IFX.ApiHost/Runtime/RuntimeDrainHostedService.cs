namespace IFX.ApiHost.Runtime;

public sealed class RuntimeDrainHostedService(
    RuntimeDrainCoordinator coordinator,
    RuntimeLifecycle lifecycle,
    RuntimeDrainOptions options,
    IHostApplicationLifetime lifetime,
    ILogger<RuntimeDrainHostedService> logger) : IHostedService
{
    private IDisposable? _stoppingRegistration;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _stoppingRegistration = lifetime.ApplicationStopping.Register(coordinator.BeginDrain);
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        coordinator.BeginDrain();
        var drainBudget = options.ProcessGrace - options.TelemetryFlushReserve;
        var drained = await coordinator.WaitForIdleAsync(drainBudget, cancellationToken);

        if (drained)
        {
            logger.LogInformation("Runtime drain completed with no in-flight operations");
        }
        else
        {
            logger.LogWarning(
                "Runtime drain timed out with {InFlight} operations; durable work remains reclaimable ({ReasonCode})",
                coordinator.InFlight,
                "G04-DRAIN-TIMEOUT");
        }

        lifecycle.MarkTerminated();
        _stoppingRegistration?.Dispose();
    }
}
