namespace IFX.Modules.Transaction.Application.DTOs;

public record OrderDto(
    Guid OrderId,
    Guid TenantId,
    string OrderType,
    string OrderReference,
    string? DealReference,
    string Status,
    string? RejectionReason,
    string? ExpectedTradeDate,
    string? ExpectedSettlementDate,
    IReadOnlyList<OrderLegDto> Legs,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt
);
