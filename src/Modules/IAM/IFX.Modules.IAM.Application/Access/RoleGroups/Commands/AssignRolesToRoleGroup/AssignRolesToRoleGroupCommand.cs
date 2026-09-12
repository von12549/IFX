using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Commands.AssignRolesToRoleGroup;

public record AssignRolesToRoleGroupCommand(Guid RoleGroupId, List<Guid> RoleIds) : ICommand<Result<RoleGroupDto>, AuthTransactionOwner>
{
    public IFX.BuildingBlocks.Application.Transactions.TransactionProfile TransactionProfile => IFX.BuildingBlocks.Application.Transactions.TransactionProfile.ConsistentReadWrite;
}
