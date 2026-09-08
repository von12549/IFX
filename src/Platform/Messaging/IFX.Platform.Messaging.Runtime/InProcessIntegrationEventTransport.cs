using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Runtime;

public sealed class InProcessIntegrationEventTransport(IServiceScopeFactory scopeFactory) : IIntegrationEventSender
{
    public async Task SendAsync(OutboxLogicalMessage message, CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var handlers = scope.ServiceProvider.GetServices<IInboundIntegrationEventHandler>()
            .Where(handler => handler.CanHandle(message.Envelope.EventType, message.Envelope.SchemaVersion))
            .ToArray();
        if (handlers.Length == 0)
        {
            throw new InvalidOperationException($"No inbound adapter is registered for '{message.Envelope.EventType}'.");
        }

        foreach (var handler in handlers)
        {
            await handler.HandleAsync(message, cancellationToken);
        }
    }
}
