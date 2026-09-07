using IFX.BuildingBlocks.Application.Events;
using IFX.Platform.Messaging.Abstractions;

namespace IFX.Platform.Messaging.Infrastructure.InMemory;

public sealed class InMemoryCommittedEventBuffer(IIntegrationEventBus eventBus) : ICommittedEventBuffer
{
    private readonly List<Func<CancellationToken, Task>> _dispatchers = [];

    public void Add<TEvent>(TEvent @event)
        where TEvent : notnull
    {
        if (@event is not IIntegrationEvent integrationEvent)
        {
            throw new ArgumentException(
                $"Event '{@event.GetType().FullName}' must implement {nameof(IIntegrationEvent)}.",
                nameof(@event));
        }

        _dispatchers.Add(token => eventBus.PublishAsync(integrationEvent, token));
    }

    public async Task DispatchAfterCommitAsync(CancellationToken cancellationToken)
    {
        var dispatchers = _dispatchers.ToArray();
        _dispatchers.Clear();

        foreach (var dispatch in dispatchers)
        {
            await dispatch(cancellationToken);
        }
    }

    public void Clear() => _dispatchers.Clear();
}
