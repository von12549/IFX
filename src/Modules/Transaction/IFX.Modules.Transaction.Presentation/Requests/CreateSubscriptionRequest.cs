namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateSubscriptionRequest(Guid InvestmentAccountId, Guid FundId, Guid ClassId, decimal Amount, string TradeDate);
