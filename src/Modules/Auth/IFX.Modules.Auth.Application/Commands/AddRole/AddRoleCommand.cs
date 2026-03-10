using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.AddRole;

public record AddRoleCommand(
    string RoleName,
    string Description) : IRequest<Result<UserRoleDto>>;
