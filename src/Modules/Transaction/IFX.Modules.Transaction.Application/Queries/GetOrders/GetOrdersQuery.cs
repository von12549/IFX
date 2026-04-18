using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Queries.GetOrders;

public record GetOrdersQuery : IRequest<Result<IReadOnlyList<OrderSummaryDto>>>;
