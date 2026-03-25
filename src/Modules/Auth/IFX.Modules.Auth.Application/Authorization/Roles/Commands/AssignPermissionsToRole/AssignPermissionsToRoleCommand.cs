using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.AssignPermissionsToRole;

public record AssignPermissionsToRoleCommand(Guid RoleId, List<Guid> PermissionIds) : IRequest<Result<RoleDetailDto>>;
