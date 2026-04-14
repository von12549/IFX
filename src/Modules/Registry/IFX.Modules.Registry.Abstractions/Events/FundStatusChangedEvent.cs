using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record FundStatusChangedEvent(
    Guid FundId,
    Guid TenantId,
    string OldStatus,
    string NewStatus) : IntegrationEvent;
