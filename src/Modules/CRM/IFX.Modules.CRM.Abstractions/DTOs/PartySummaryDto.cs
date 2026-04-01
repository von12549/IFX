namespace IFX.Modules.CRM.Abstractions.DTOs;

public record PartySummaryDto(Guid PartyId, string PartyCode, string Name, string PartyType, string Status);
