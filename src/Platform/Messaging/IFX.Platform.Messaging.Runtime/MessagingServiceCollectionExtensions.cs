using IFX.BuildingBlocks.Application.Events;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Runtime;

public static class MessagingServiceCollectionExtensions
{
    public static IServiceCollection AddMessagingRuntime(this IServiceCollection services)
    {
        services.AddScoped<BufferedIntegrationEventSource>();
        services.AddScoped<ICommittedEventBuffer>(provider => provider.GetRequiredService<BufferedIntegrationEventSource>());
        services.AddScoped<IPendingIntegrationEventSource>(provider => provider.GetRequiredService<BufferedIntegrationEventSource>());
        services.AddScoped<IOutboxMessageFactory, OutboxMessageFactory>();
        services.AddSingleton<IIntegrationEventSender, InProcessIntegrationEventTransport>();
        services.AddSingleton<MessagingTelemetry>();
        return services;
    }

    public static IServiceCollection AddOutboxDispatcher(this IServiceCollection services, string leaseOwner, Action<OutboxDispatcherOptions>? configure = null)
    {
        if (configure is not null) services.Configure(configure);
        else services.Configure<OutboxDispatcherOptions>(_ => { });
        services.AddSingleton(leaseOwner);
        services.AddHostedService<OutboxDispatcherHostedService>();
        return services;
    }
}
