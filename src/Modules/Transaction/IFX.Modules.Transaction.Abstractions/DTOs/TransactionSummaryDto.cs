namespace IFX.Modules.Transaction.Abstractions.DTOs;

public record TransactionSummaryDto(
    Guid TransactionId,
    Guid TenantId,
    string TransactionType,
    Guid InvestorId,
    Guid ClassId,
    decimal Amount,
    string Status
);
