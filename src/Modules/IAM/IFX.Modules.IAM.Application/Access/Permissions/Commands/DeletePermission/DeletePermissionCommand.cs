using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Permissions.Commands.DeletePermission;

public record DeletePermissionCommand(Guid PermissionId) : ICommand<Result<bool>, AuthTransactionOwner>;
