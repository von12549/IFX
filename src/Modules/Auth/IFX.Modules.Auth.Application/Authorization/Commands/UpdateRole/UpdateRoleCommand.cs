using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.UpdateRole;

public record UpdateRoleCommand(
    Guid RoleId,
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
