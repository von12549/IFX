using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.AssignPermissionsToRole;

public record AssignPermissionsToRoleCommand(Guid RoleId, List<Guid> PermissionIds) : IRequest<Result<RoleDetailDto>>;
