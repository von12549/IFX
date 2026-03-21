using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateRoleGroup;

public record CreateRoleGroupCommand(string Name, string Description) : IRequest<Result<RoleGroupDto>>;
