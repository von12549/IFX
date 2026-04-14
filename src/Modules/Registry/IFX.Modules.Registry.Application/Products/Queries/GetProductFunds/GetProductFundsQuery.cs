using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Products.Queries.GetProductFunds;

public record GetProductFundsQuery(Guid ProductId) : IRequest<Result<List<FundDto>>>;
