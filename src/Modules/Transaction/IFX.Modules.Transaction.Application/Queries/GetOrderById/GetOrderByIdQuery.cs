using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Queries.GetOrderById;

public record GetOrderByIdQuery(Guid OrderId) : IRequest<Result<OrderDto>>;
