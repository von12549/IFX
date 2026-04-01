using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.Funds.Commands.DeleteFund;

public record DeleteFundCommand(Guid FundId) : IRequest<Result<FundDto>>;
