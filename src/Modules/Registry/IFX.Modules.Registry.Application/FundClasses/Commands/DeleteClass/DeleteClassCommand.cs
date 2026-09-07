using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.DeleteClass;

public record DeleteClassCommand(Guid ClassId, Guid FundId) : ICommand<Result<FundClassDto>, RegistryTransactionOwner>;
