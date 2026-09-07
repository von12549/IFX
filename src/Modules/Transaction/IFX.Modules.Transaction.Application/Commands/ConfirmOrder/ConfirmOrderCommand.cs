using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Commands.ConfirmOrder;

public record OrderLegConfirmation(
    Guid TransactionId,
    decimal NAVPrice,
    decimal Units,
    string? PriceType,
    DateOnly? SettlementDate
);

public record ConfirmOrderCommand(
    Guid OrderId,
    IReadOnlyList<OrderLegConfirmation> Legs
) : ICommand<Result<OrderDto>, TransactionModuleOwner>;
