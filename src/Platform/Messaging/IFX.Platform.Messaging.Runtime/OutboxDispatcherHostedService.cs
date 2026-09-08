using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace IFX.Platform.Messaging.Runtime;

public sealed class OutboxDispatcherHostedService(
    IServiceScopeFactory scopeFactory,
    IIntegrationEventSender transport,
    IRuntimeDrainSignal drain,
    IOptions<OutboxDispatcherOptions> options,
    string leaseOwner,
    ILogger<OutboxDispatcherHostedService> logger) : BackgroundService
{
    private readonly OutboxDispatcherOptions _options = Validate(options.Value);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested && drain.AcceptingNewWork)
        {
            await DispatchOnceAsync(stoppingToken);
            await Task.Delay(_options.PollInterval, stoppingToken);
        }
    }

    internal async Task DispatchOnceAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var stores = scope.ServiceProvider.GetServices<IModuleOutboxStore>().ToArray();
        foreach (var store in stores)
        {
            var now = DateTimeOffset.UtcNow;
            var leases = await store.ClaimAsync(new OutboxClaimRequest(leaseOwner, now, now + _options.LeaseDuration, _options.BatchSize), cancellationToken);
            foreach (var lease in leases)
            {
                try
                {
                    using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, drain.DrainToken);
                    timeout.CancelAfter(_options.SendTimeout);
                    await transport.SendAsync(lease.Message, timeout.Token);
                    await store.CompleteAsync(lease, DateTimeOffset.UtcNow, cancellationToken);
                    logger.LogInformation("Outbox delivered {ModuleId} {EventType} {EventId}", store.ModuleId, lease.Message.Envelope.EventType, lease.Message.Envelope.EventId);
                }
                catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
                {
                    var attempt = Math.Max(1, await RetryAttemptAsync(store, lease, exception, cancellationToken));
                    logger.LogWarning(exception, "Outbox delivery failed {ModuleId} {EventType} attempt {Attempt}", store.ModuleId, lease.Message.Envelope.EventType, attempt);
                }
            }
        }
    }

    private async Task<int> RetryAttemptAsync(IModuleOutboxStore store, OutboxDispatchLease lease, Exception exception, CancellationToken cancellationToken)
    {
        var attempt = lease.AttemptCount;
        var deadLetter = attempt >= _options.MaximumAttempts;
        var exponent = Math.Min(attempt - 1, 20);
        var backoff = TimeSpan.FromSeconds(Math.Min(Math.Pow(2, exponent), _options.MaximumBackoff.TotalSeconds));
        var jitter = TimeSpan.FromMilliseconds(Random.Shared.Next(0, 500));
        await store.FailAsync(lease, DateTimeOffset.UtcNow + backoff + jitter, exception.GetType().Name, deadLetter, cancellationToken);
        return attempt;
    }

    private static OutboxDispatcherOptions Validate(OutboxDispatcherOptions options)
    {
        options.Validate();
        return options;
    }
}
