namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateRedemptionRequest(Guid InvestmentAccountId, Guid FundId, Guid ClassId, decimal Amount, string TradeDate);
