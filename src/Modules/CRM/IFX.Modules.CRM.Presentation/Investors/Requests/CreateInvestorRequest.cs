namespace IFX.Modules.CRM.Presentation.Investors.Requests;

public record CreateInvestorRequest(string InvestorCode, string Name, string LegalStructure, string? TaxResidencyCountry = null, Guid? PartyId = null);
