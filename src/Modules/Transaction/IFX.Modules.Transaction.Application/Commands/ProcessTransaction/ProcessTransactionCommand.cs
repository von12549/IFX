using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
public record ProcessTransactionCommand(Guid TransactionId, decimal NAVPrice) : IRequest<Result<TransactionDto>>;
