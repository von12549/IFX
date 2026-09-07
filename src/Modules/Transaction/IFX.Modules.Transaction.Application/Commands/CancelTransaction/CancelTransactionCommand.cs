using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.CancelTransaction;
public record CancelTransactionCommand(Guid TransactionId, string? Reason = null) : ICommand<Result<TransactionDto>, TransactionModuleOwner>;
