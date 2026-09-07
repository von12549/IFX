using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
public record ProcessTransactionCommand(Guid TransactionId, decimal NAVPrice) : ICommand<Result<TransactionDto>, TransactionModuleOwner>;
