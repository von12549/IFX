using IFX.Platform.Messaging.Abstractions;
using IFX.Platform.Messaging.Infrastructure.InMemory;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Composition;

public static class MessagingServiceCollectionExtensions
{
    /// <summary>
    /// Registers the in-memory integration event bus.
    /// Call AddIntegrationEventHandler&lt;TEvent, THandler&gt;() in each module's
    /// Composition layer to register handlers.
    /// </summary>
    public static IServiceCollection AddMessaging(this IServiceCollection services)
    {
        services.AddScoped<IIntegrationEventBus, InMemoryIntegrationEventBus>();
        return services;
    }

    /// <summary>
    /// Registers an integration event handler. Call this in each module's Composition layer.
    /// </summary>
    public static IServiceCollection AddIntegrationEventHandler<TEvent, THandler>(
        this IServiceCollection services)
        where TEvent : IIntegrationEvent
        where THandler : class, IIntegrationEventHandler<TEvent>
    {
        services.AddScoped<IIntegrationEventHandler<TEvent>, THandler>();
        return services;
    }
}
