namespace IFX.Modules.Holdings.Abstractions.DTOs;

public record HoldingSummaryDto(
    Guid HoldingId,
    Guid TenantId,
    Guid InvestmentAccountId,
    Guid ClassId,
    decimal Units,
    string Status,
    DateTimeOffset? LastTransactionAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt
);
