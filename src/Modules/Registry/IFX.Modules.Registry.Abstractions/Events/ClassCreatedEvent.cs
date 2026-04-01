using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record ClassCreatedEvent(
    Guid ClassId,
    Guid FundId,
    Guid TenantId,
    string ClassCode) : IntegrationEvent;
