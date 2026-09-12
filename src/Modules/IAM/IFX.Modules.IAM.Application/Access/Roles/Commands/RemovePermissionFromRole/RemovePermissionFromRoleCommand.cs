using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.RemovePermissionFromRole;

public record RemovePermissionFromRoleCommand(Guid RoleId, Guid PermissionId) : ICommand<Result<bool>, AuthTransactionOwner>;
