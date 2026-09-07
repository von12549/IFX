using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Domain.Enums;
using MediatR;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.CreateClass;

public record CreateClassCommand(
    Guid FundId,
    string ClassCode,
    string ClassName,
    string Currency,
    NavFrequency NavFrequency,
    decimal? MinInitialInvestment,
    decimal? ManagementFeeRate,
    decimal? PerformanceFeeRate) : ICommand<Result<FundClassDto>, RegistryTransactionOwner>;
