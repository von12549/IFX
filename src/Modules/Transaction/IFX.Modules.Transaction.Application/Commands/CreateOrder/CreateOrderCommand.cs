using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Commands.CreateOrder;

public record CreateOrderCommand(
    string OrderType,
    string OrderReference,
    Guid InvestmentAccountId,
    Guid FromFundId,
    Guid FromClassId,
    Guid? ToFundId,
    Guid? ToClassId,
    decimal Amount,
    string Currency,
    DateOnly TradeDate
) : IRequest<Result<OrderDto>>;
