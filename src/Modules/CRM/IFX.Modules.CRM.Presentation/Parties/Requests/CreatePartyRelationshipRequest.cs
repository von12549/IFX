namespace IFX.Modules.CRM.Presentation.Parties.Requests;

public record CreatePartyRelationshipRequest(Guid ToPartyId, string RelationshipType, string EffectiveDate);
