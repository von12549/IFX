using IFX.Platform.Messaging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Platform.Messaging.Infrastructure.InMemory;

public sealed class InMemoryIntegrationEventBus : IIntegrationEventBus
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<InMemoryIntegrationEventBus> _logger;

    public InMemoryIntegrationEventBus(
        IServiceProvider serviceProvider,
        ILogger<InMemoryIntegrationEventBus> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public Task PublishAsync(IIntegrationEvent @event, CancellationToken ct = default)
    {
        var method = typeof(InMemoryIntegrationEventBus)
            .GetMethods()
            .Single(candidate => candidate.Name == nameof(PublishAsync) && candidate.IsGenericMethod)
            .MakeGenericMethod(@event.GetType());
        return (Task)method.Invoke(this, [@event, ct])!;
    }

    public async Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : IIntegrationEvent
    {
        var eventType = typeof(TEvent).Name;
        _logger.LogDebug("Publishing integration event {EventType} ({EventId})", eventType, @event.EventId);

        var handlers = _serviceProvider.GetServices<IIntegrationEventHandler<TEvent>>();
        List<Exception>? failures = null;

        foreach (var handler in handlers)
        {
            try
            {
                await handler.HandleAsync(@event, ct);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Error handling integration event {EventType} ({EventId}) in handler {Handler}",
                    eventType, @event.EventId, handler.GetType().Name);
                (failures ??= []).Add(ex);
            }
        }

        if (failures is not null)
        {
            throw new AggregateException(
                $"One or more handlers failed for integration event '{eventType}' ({@event.EventId}).",
                failures);
        }
    }
}
