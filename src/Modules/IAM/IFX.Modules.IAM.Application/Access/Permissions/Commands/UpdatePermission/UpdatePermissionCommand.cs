using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Access.Permissions.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Permissions.Commands.UpdatePermission;

public record UpdatePermissionCommand(Guid PermissionId, string Name, string Description) : ICommand<Result<PermissionDto>, AuthTransactionOwner>;
