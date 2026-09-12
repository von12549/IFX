using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.AssignPermissionsToRole;

public record AssignPermissionsToRoleCommand(Guid RoleId, List<Guid> PermissionIds) : ICommand<Result<RoleDetailDto>, AuthTransactionOwner>
{
    public IFX.BuildingBlocks.Application.Transactions.TransactionProfile TransactionProfile => IFX.BuildingBlocks.Application.Transactions.TransactionProfile.ConsistentReadWrite;
}
