using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.Holdings.Abstractions.Events;

public record HoldingFrozenEvent(
    Guid HoldingId,
    Guid TenantId,
    Guid ClassId,
    Guid InvestorId
) : IntegrationEvent;
