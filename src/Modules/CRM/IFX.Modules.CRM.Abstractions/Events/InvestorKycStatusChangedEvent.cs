using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record InvestorKycStatusChangedEvent(Guid InvestorId, Guid TenantId, string OldStatus, string NewStatus) : IntegrationEvent;
