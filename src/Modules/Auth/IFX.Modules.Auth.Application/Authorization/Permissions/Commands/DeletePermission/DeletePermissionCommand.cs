using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Commands.DeletePermission;

public record DeletePermissionCommand(Guid PermissionId) : ICommand<Result<bool>, AuthTransactionOwner>;
