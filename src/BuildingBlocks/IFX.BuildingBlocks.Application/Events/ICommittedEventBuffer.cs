namespace IFX.BuildingBlocks.Application.Events;

/// <summary>
/// Process-local seam for facts that must not reach transport before the local transaction commits.
/// Plan 02 E2 replaces the transitional dispatcher with a module-local Outbox participant.
/// </summary>
public interface ICommittedEventBuffer
{
    void Add<TEvent>(TEvent @event)
        where TEvent : notnull;

    Task DispatchAfterCommitAsync(CancellationToken cancellationToken);

    void Clear();
}

/// <summary>
/// Transaction participant seam used by a module-owned Outbox. Reading drains the current
/// command's immutable event snapshots; transport code never sees this process-local buffer.
/// </summary>
public interface IPendingIntegrationEventSource
{
    IReadOnlyList<object> Drain();
}
