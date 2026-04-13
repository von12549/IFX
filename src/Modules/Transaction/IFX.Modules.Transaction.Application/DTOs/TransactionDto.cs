namespace IFX.Modules.Transaction.Application.DTOs;
public record TransactionDto(
    Guid TransactionId,
    Guid TenantId,
    string Type,
    Guid InvestmentAccountId,
    Guid FundId,
    Guid ClassId,
    Guid? TargetClassId,
    decimal Amount,
    decimal? Units,
    decimal? NAVPrice,
    string TradeDate,
    string? SettlementDate,
    string Status,
    string? FailureReason,
    DateTime CreatedAt,
    DateTime UpdatedAt
);
