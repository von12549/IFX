using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.DeletePolicy;

public record DeletePolicyCommand(Guid PolicyId) : ICommand<Result<bool>, AuthTransactionOwner>;
