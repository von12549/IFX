using IFX.BuildingBlocks.Application.Events;

namespace IFX.Platform.Messaging.Runtime;

public sealed class BufferedIntegrationEventSource : ICommittedEventBuffer, IPendingIntegrationEventSource
{
    private readonly List<object> _events = [];

    public void Add<TEvent>(TEvent @event) where TEvent : notnull => _events.Add(@event);

    public IReadOnlyList<object> Drain()
    {
        var pending = _events.ToArray();
        _events.Clear();
        return pending;
    }

    public Task DispatchAfterCommitAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public void Clear() => _events.Clear();
}
