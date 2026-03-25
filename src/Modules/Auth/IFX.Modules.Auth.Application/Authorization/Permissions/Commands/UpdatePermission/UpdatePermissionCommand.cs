using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Commands.UpdatePermission;

public record UpdatePermissionCommand(Guid PermissionId, string Name, string Description) : IRequest<Result<PermissionDto>>;
