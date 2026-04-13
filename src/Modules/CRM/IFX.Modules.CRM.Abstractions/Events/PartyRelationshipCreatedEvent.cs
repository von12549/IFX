using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record PartyRelationshipCreatedEvent(Guid RelationshipId, Guid TenantId, Guid FromPartyId, Guid ToPartyId, string RelationshipType) : IntegrationEvent;
