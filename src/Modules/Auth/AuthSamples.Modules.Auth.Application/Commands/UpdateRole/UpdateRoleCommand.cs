using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateRole;

public record UpdateRoleCommand(
    Guid RoleId,
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
