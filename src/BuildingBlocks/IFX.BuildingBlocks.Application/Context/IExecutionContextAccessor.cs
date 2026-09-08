namespace IFX.BuildingBlocks.Application.Context;

public interface IExecutionContextAccessor
{
    bool HasCurrent { get; }

    ExecutionContextSnapshot Current { get; }
}

public interface IExecutionContextScopeFactory
{
    IDisposable Push(ExecutionContextSnapshot context);

    Task RunAsync(
        ExecutionContextSnapshot context,
        Func<CancellationToken, Task> operation,
        CancellationToken cancellationToken = default);

    Task RunDetachedAsync(Func<CancellationToken, Task> operation, CancellationToken cancellationToken = default);
}
