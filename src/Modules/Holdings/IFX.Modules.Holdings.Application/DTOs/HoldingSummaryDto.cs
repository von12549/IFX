namespace IFX.Modules.Holdings.Application.DTOs;

public sealed record HoldingSummaryDto(
    Guid HoldingId,
    Guid TenantId,
    Guid InvestmentAccountId,
    Guid ClassId,
    decimal Units,
    string Status,
    DateTimeOffset? LastTransactionAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
