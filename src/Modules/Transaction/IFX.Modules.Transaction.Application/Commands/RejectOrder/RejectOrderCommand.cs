using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;

namespace IFX.Modules.Transaction.Application.Commands.RejectOrder;

public record RejectOrderCommand(Guid OrderId, string Reason) : ICommand<Result<OrderDto>, TransactionModuleOwner>;
