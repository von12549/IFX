using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.RemovePermissionFromRole;

public record RemovePermissionFromRoleCommand(Guid RoleId, Guid PermissionId) : IRequest<Result<bool>>;
