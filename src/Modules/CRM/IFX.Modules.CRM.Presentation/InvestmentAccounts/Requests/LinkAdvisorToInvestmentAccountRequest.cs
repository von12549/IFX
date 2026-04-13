namespace IFX.Modules.CRM.Presentation.InvestmentAccounts.Requests;

public record LinkAdvisorToInvestmentAccountRequest(string EffectiveDate, decimal? RebateRate = null);
