namespace IFX.ApiHost.Runtime;

public sealed record RuntimeCapabilities(
    bool Api,
    bool HangfireClient,
    bool HangfireServer,
    bool Dispatcher,
    bool Consumers,
    bool RecurringScheduler)
{
    public bool HasWorkerExecution => HangfireServer || Dispatcher || Consumers || RecurringScheduler;
}
