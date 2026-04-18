using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Commands.CancelOrder;

public record CancelOrderCommand(Guid OrderId, string? Reason) : IRequest<Result<OrderDto>>;
