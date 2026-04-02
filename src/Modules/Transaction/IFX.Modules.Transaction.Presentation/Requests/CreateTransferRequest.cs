namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateTransferRequest(Guid PartyId, Guid InvestorId, Guid FundId, Guid ClassId, Guid TargetClassId, decimal Amount, string TradeDate);
