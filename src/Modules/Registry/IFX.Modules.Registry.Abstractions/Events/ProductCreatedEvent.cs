using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record ProductCreatedEvent(
    Guid ProductId,
    Guid TenantId,
    string ProductCode,
    string ProductName) : IntegrationEvent;
