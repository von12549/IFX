namespace IFX.Modules.Transaction.Presentation.Requests;

public record CreateOrderRequest(
    string OrderType,
    string OrderReference,
    Guid InvestmentAccountId,
    Guid FromFundId,
    Guid FromClassId,
    Guid? ToFundId,
    Guid? ToClassId,
    decimal Amount,
    string Currency,
    string TradeDate
);
