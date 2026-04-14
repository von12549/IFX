namespace IFX.Modules.CRM.Presentation.InvestmentAccounts.Requests;

public record CreateInvestmentAccountRequest(string AccountNumber, string AccountType, string? CertificateDate = null);
