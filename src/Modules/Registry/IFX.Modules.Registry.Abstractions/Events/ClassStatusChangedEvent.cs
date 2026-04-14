using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record ClassStatusChangedEvent(
    Guid ClassId,
    Guid FundId,
    Guid TenantId,
    string OldStatus,
    string NewStatus) : IntegrationEvent;
