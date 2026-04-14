using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record InvestorCreatedEvent(Guid InvestorId, Guid TenantId, string InvestorCode, string Name) : IntegrationEvent;
