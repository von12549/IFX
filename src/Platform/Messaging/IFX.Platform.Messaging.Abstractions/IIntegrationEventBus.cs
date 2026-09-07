namespace IFX.Platform.Messaging.Abstractions;

public interface IIntegrationEventBus
{
    Task PublishAsync(IIntegrationEvent @event, CancellationToken ct = default);

    Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : IIntegrationEvent;
}
