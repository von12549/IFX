namespace IFX.Modules.CRM.Presentation.Investors.Requests;

public record UpdateInvestorRequest(string Name, string? TaxResidencyCountry = null, string? TIN = null, string? GIIN = null);
