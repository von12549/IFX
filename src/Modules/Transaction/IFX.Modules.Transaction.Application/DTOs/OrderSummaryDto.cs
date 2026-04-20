namespace IFX.Modules.Transaction.Application.DTOs;

public record OrderSummaryDto(
    Guid OrderId,
    Guid TenantId,
    string OrderType,
    string OrderReference,
    string? DealReference,
    string Status,
    int LegCount,
    DateTimeOffset CreatedAt
);
