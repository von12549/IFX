using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.AddRole;

public record AddRoleCommand(
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
