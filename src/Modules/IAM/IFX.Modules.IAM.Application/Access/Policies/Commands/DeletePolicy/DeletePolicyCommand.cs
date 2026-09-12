using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.DeletePolicy;

public record DeletePolicyCommand(Guid PolicyId) : ICommand<Result<bool>, AuthTransactionOwner>;
