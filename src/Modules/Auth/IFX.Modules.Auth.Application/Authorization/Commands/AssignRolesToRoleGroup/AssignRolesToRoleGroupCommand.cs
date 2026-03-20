using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.AssignRolesToRoleGroup;

public record AssignRolesToRoleGroupCommand(Guid RoleGroupId, List<Guid> RoleIds) : IRequest<Result<RoleGroupDto>>;
