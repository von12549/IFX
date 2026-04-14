using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Queries.GetTransactionById;
public record GetTransactionByIdQuery(Guid TransactionId) : IRequest<Result<TransactionDto>>;
