namespace IFX.Modules.CRM.Presentation.InvestmentAccounts.Requests;

public record UpdateInvestmentAccountRequest(string AccountNumber, string AccountType, string? CertificateDate = null);
