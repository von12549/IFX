namespace IFX.Modules.Holdings.Abstractions.DTOs;

public record HoldingSummaryDto(
    Guid HoldingId,
    Guid TenantId,
    Guid InvestorId,
    Guid ClassId,
    decimal Units,
    string Status,
    DateTime? LastTransactionAt,
    DateTime CreatedAt,
    DateTime UpdatedAt
);
