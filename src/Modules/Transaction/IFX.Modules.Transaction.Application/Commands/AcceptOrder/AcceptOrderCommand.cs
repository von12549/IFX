using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Commands.AcceptOrder;

public record AcceptOrderCommand(
    Guid OrderId,
    string DealReference,
    DateOnly? ExpectedTradeDate,
    DateOnly? ExpectedSettlementDate
) : IRequest<Result<OrderDto>>;
