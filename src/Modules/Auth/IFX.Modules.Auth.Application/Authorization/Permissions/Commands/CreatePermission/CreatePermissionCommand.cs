using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Commands.CreatePermission;

public record CreatePermissionCommand(string Name, string Description) : IRequest<Result<PermissionDto>>;
