using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.UpdateRole;

public record UpdateRoleCommand(
    Guid RoleId,
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
