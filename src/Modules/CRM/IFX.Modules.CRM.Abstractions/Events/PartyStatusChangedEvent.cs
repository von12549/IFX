using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record PartyStatusChangedEvent(Guid PartyId, Guid TenantId, string OldStatus, string NewStatus) : IntegrationEvent;
