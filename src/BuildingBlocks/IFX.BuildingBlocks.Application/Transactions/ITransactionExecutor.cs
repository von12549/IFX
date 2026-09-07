namespace IFX.BuildingBlocks.Application.Transactions;

public interface ITransactionExecutor
{
    Type OwnerType { get; }

    Task ExecutePersistenceAsync(
        Func<CancellationToken, Task> prepareAsync,
        CancellationToken cancellationToken);

    Task ExecuteAtomicAsync(
        Func<CancellationToken, Task> operationAsync,
        CancellationToken cancellationToken);

    ValueTask DiscardChangesAsync(CancellationToken cancellationToken);
}

public interface ITransactionParticipant
{
    Task PrepareAsync(object command, object? response, CancellationToken cancellationToken);
}
