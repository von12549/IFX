namespace IFX.Modules.CRM.Presentation.Investors.Requests;

public record CreateInvestorRequest(string InvestorCode, string Name, string Type, string ResidencyCountry, string TaxResidency);
