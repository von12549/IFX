using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Registry.Abstractions.Events;

public record FundCreatedEvent(
    Guid FundId,
    Guid TenantId,
    string FundCode,
    string FundName) : IntegrationEvent;
