namespace IFX.Modules.CRM.Abstractions.DTOs;

public record InvestorSummaryDto(Guid InvestorId, string InvestorCode, string Name, string LegalStructure, string KycStatus, string? TaxResidencyCountry, string Status);
