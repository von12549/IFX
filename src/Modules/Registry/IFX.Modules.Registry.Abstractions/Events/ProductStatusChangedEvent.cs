using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record ProductStatusChangedEvent(
    Guid ProductId,
    Guid TenantId,
    string NewStatus) : IntegrationEvent;
