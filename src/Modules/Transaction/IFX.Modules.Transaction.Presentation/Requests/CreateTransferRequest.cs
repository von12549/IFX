namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateTransferRequest(Guid InvestmentAccountId, Guid FundId, Guid ClassId, Guid TargetClassId, decimal Amount, string TradeDate);
