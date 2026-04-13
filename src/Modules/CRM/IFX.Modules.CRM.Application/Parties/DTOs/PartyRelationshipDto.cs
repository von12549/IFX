namespace IFX.Modules.CRM.Application.Parties.DTOs;

public record PartyRelationshipDto(
    Guid Id,
    Guid TenantId,
    Guid FromPartyId,
    Guid ToPartyId,
    string RelationshipType,
    string EffectiveDate,
    string? ExpiryDate,
    DateTime CreatedAt);
