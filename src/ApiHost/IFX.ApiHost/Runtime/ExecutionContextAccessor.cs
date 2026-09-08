using System.Threading;
using IFX.BuildingBlocks.Application.Context;

namespace IFX.ApiHost.Runtime;

public sealed class ExecutionContextAccessor : IExecutionContextAccessor, IExecutionContextScopeFactory
{
    private readonly AsyncLocal<ScopeFrame?> _current = new();

    public bool HasCurrent => _current.Value is not null;

    public ExecutionContextSnapshot Current => _current.Value?.Context
        ?? throw new InvalidOperationException("No trusted execution context is active.");

    public IDisposable Push(ExecutionContextSnapshot context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var frame = new ScopeFrame(context, _current.Value);
        _current.Value = frame;
        return new ScopeLease(this, frame);
    }

    public async Task RunAsync(
        ExecutionContextSnapshot context,
        Func<CancellationToken, Task> operation,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(operation);
        using var scope = Push(context);
        await operation(cancellationToken).ConfigureAwait(false);
    }

    public Task RunDetachedAsync(
        Func<CancellationToken, Task> operation,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(operation);
        if (System.Threading.ExecutionContext.IsFlowSuppressed())
        {
            return Task.Run(() => operation(cancellationToken), cancellationToken);
        }

        Task task;
        using (System.Threading.ExecutionContext.SuppressFlow())
        {
            task = Task.Run(() => operation(cancellationToken), cancellationToken);
        }

        return task;
    }

    private void Pop(ScopeFrame frame)
    {
        if (!ReferenceEquals(_current.Value, frame))
        {
            throw new InvalidOperationException("Execution contexts must be disposed in reverse order.");
        }

        _current.Value = frame.Parent;
    }

    private sealed record ScopeFrame(ExecutionContextSnapshot Context, ScopeFrame? Parent);

    private sealed class ScopeLease(ExecutionContextAccessor owner, ScopeFrame frame) : IDisposable
    {
        private readonly object _sync = new();
        private int _disposed;

        public void Dispose()
        {
            lock (_sync)
            {
                if (_disposed != 0)
                {
                    return;
                }

                owner.Pop(frame);
                _disposed = 1;
            }
        }
    }
}
