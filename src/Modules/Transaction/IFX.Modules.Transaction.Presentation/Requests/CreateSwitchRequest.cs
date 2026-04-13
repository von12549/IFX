namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateSwitchRequest(Guid InvestmentAccountId, Guid FundId, Guid ClassId, Guid TargetClassId, decimal Amount, string TradeDate);
