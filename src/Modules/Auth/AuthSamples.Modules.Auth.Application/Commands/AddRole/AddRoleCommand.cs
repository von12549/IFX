using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.AddRole;

public record AddRoleCommand(
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
