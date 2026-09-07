namespace IFX.ApiHost.Runtime;

public enum RuntimeLifecycleState
{
    Starting,
    AliveNotReady,
    Ready,
    Degraded,
    Stopping,
    Terminated
}

public sealed record RuntimeLifecycleSnapshot(RuntimeLifecycleState State, string ReasonCode, DateTimeOffset ChangedAt);

public sealed class RuntimeLifecycle
{
    private RuntimeLifecycleSnapshot _snapshot = new(RuntimeLifecycleState.Starting, "G04-STARTING", DateTimeOffset.UtcNow);

    public RuntimeLifecycleSnapshot Snapshot => Volatile.Read(ref _snapshot);

    public void MarkAliveNotReady(string reasonCode) => Set(RuntimeLifecycleState.AliveNotReady, reasonCode);
    public void MarkReady() => Set(RuntimeLifecycleState.Ready, "G04-READY");
    public void MarkDegraded(string reasonCode) => Set(RuntimeLifecycleState.Degraded, reasonCode);
    public void MarkStopping() => Set(RuntimeLifecycleState.Stopping, "G04-STOPPING");
    public void MarkTerminated() => Set(RuntimeLifecycleState.Terminated, "G04-TERMINATED");

    private void Set(RuntimeLifecycleState state, string reasonCode) =>
        Volatile.Write(ref _snapshot, new RuntimeLifecycleSnapshot(state, reasonCode, DateTimeOffset.UtcNow));
}
