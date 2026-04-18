namespace IFX.Modules.Transaction.Presentation.Requests;

public record AcceptOrderRequest(
    string DealReference,
    string? ExpectedTradeDate,
    string? ExpectedSettlementDate
);
