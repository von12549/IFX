using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Domain.Enums;
using MediatR;

namespace IFX.Modules.Registry.Application.Funds.Commands.UpdateFund;

public record UpdateFundCommand(
    Guid FundId,
    string FundName,
    FundType FundType,
    string BaseCurrency,
    Guid? ProductId = null,
    bool ClearProduct = false) : ICommand<Result<FundDto>, RegistryTransactionOwner>;
