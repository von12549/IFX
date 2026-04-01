using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Domain.Enums;
using MediatR;

namespace IFX.Modules.Registry.Application.Funds.Commands.CreateFund;

public record CreateFundCommand(
    string FundCode,
    string FundName,
    FundType FundType,
    string BaseCurrency,
    DateOnly InceptionDate) : IRequest<Result<FundDto>>;
