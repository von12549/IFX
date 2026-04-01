using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record PartyCreatedEvent(Guid PartyId, Guid TenantId, string PartyCode, string Name) : IntegrationEvent;
