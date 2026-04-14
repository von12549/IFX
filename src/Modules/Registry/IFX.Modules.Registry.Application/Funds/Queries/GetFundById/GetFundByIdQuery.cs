using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Funds.Queries.GetFundById;

public record GetFundByIdQuery(Guid FundId) : IRequest<Result<FundDto>>;
