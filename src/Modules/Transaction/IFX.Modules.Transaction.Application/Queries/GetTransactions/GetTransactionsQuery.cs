using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using MediatR;
namespace IFX.Modules.Transaction.Application.Queries.GetTransactions;
public record GetTransactionsQuery() : IRequest<Result<IReadOnlyList<TransactionDto>>>;
