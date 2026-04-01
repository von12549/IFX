namespace IFX.Modules.CRM.Abstractions.DTOs;

public record InvestorSummaryDto(Guid InvestorId, string InvestorCode, string Name, string InvestorType, string KycStatus, string ResidencyCountry, string TaxResidency, string Status);
