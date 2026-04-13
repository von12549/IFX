namespace IFX.Modules.Transaction.Abstractions.DTOs;

public record TransactionSummaryDto(
    Guid TransactionId,
    Guid TenantId,
    string TransactionType,
    Guid InvestmentAccountId,
    Guid ClassId,
    decimal Amount,
    string Status
);
