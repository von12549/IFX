namespace IFX.Modules.Transaction.Presentation.Requests;
public record CreateSwitchRequest(Guid PartyId, Guid InvestorId, Guid FundId, Guid ClassId, Guid TargetClassId, decimal Amount, string TradeDate);
