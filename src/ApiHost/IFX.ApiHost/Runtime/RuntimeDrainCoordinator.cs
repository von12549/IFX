using IFX.Platform.Messaging.Composition;

namespace IFX.ApiHost.Runtime;

public sealed class RuntimeDrainCoordinator(RuntimeLifecycle lifecycle) : IMessagingDrainSignal
{
    private readonly CancellationTokenSource _drain = new();
    private TaskCompletionSource _idle = CompletedSource();
    private int _draining;
    private long _inFlight;

    public bool AcceptingNewWork => Volatile.Read(ref _draining) == 0;
    public CancellationToken DrainToken => _drain.Token;
    public long InFlight => Interlocked.Read(ref _inFlight);

    public bool TryBeginOperation(out IDisposable? operation)
    {
        operation = null;
        if (!AcceptingNewWork)
        {
            return false;
        }

        if (Interlocked.Increment(ref _inFlight) == 1)
        {
            Interlocked.Exchange(ref _idle, new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously));
        }

        if (!AcceptingNewWork)
        {
            CompleteOperation();
            return false;
        }

        operation = new OperationLease(this);
        return true;
    }

    public void BeginDrain()
    {
        if (Interlocked.Exchange(ref _draining, 1) != 0)
        {
            return;
        }

        lifecycle.MarkStopping();
        _drain.Cancel();
        if (InFlight == 0)
        {
            _idle.TrySetResult();
        }
    }

    public async Task<bool> WaitForIdleAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        if (InFlight == 0)
        {
            return true;
        }

        var idle = _idle.Task;
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(timeout);
        try
        {
            await idle.WaitAsync(timeoutSource.Token);
            return true;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            // The idle continuation and the timeout callback both run on the thread pool; under starvation the
            // timeout can be observed after the runtime already became idle. Idle reached first wins.
            return idle.IsCompleted;
        }
    }

    private void CompleteOperation()
    {
        if (Interlocked.Decrement(ref _inFlight) == 0)
        {
            _idle.TrySetResult();
        }
    }

    private static TaskCompletionSource CompletedSource()
    {
        var source = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        source.SetResult();
        return source;
    }

    private sealed class OperationLease(RuntimeDrainCoordinator owner) : IDisposable
    {
        private RuntimeDrainCoordinator? _owner = owner;

        public void Dispose() => Interlocked.Exchange(ref _owner, null)?.CompleteOperation();
    }
}
