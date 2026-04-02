namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateSubscriptionRequest(Guid PartyId, Guid InvestorId, Guid FundId, Guid ClassId, decimal Amount, string TradeDate);
