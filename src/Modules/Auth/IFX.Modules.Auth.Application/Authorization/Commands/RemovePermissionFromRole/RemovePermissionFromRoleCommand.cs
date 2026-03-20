using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.RemovePermissionFromRole;

public record RemovePermissionFromRoleCommand(Guid RoleId, Guid PermissionId) : IRequest<Result<bool>>;
