using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Funds.Queries.GetFunds;

public record GetFundsQuery() : IRequest<Result<List<FundDto>>>;
