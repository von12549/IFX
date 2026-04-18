namespace IFX.Modules.Transaction.Presentation.Requests;

public record ConfirmOrderLegRequest(
    Guid TransactionId,
    decimal NAVPrice,
    decimal Units,
    string? PriceType,
    string? SettlementDate
);

public record ConfirmOrderRequest(IReadOnlyList<ConfirmOrderLegRequest> Legs);
