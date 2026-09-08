using IFX.Platform.Messaging.Runtime;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Composition;

public interface IMessagingDrainSignal
{
    bool AcceptingNewWork { get; }

    CancellationToken DrainToken { get; }
}

public static class ReliableMessagingInstaller
{
    public static IServiceCollection AddReliableMessaging(
        this IServiceCollection services,
        string leaseOwner,
        bool dispatcherEnabled,
        Action<MessagingHealthThresholds>? configureHealth = null)
    {
        services.AddMessagingRuntime();
        var healthThresholds = new MessagingHealthThresholds();
        configureHealth?.Invoke(healthThresholds);
        _ = healthThresholds.ToRuntimeThreshold();
        services.AddSingleton(healthThresholds);
        services.AddSingleton<IMessagingHealthProbe, RuntimeMessagingHealthProbe>();
        services.AddSingleton<IRuntimeDrainSignal>(provider =>
            new RuntimeDrainSignalBridge(provider.GetRequiredService<IMessagingDrainSignal>()));
        if (dispatcherEnabled)
        {
            services.AddOutboxDispatcher(leaseOwner);
        }

        return services;
    }

    private sealed class RuntimeDrainSignalBridge(IMessagingDrainSignal signal) : IRuntimeDrainSignal
    {
        public bool AcceptingNewWork => signal.AcceptingNewWork;

        public CancellationToken DrainToken => signal.DrainToken;
    }
}
