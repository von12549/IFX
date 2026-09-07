using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.AssignPermissionsToRole;

public record AssignPermissionsToRoleCommand(Guid RoleId, List<Guid> PermissionIds) : ICommand<Result<RoleDetailDto>, AuthTransactionOwner>;
