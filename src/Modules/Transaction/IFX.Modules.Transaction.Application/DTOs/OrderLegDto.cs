namespace IFX.Modules.Transaction.Application.DTOs;

public record OrderLegDto(
    Guid TransactionId,
    string LegId,
    string TransactionType,
    Guid FundId,
    Guid ClassId,
    decimal Amount,
    string Currency,
    decimal? Units,
    decimal? NAVPrice,
    string? PriceType,
    string TradeDate,
    string? SettlementDate,
    string Status
);
