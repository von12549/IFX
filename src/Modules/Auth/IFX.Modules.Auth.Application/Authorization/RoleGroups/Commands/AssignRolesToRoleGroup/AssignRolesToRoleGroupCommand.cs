using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.AssignRolesToRoleGroup;

public record AssignRolesToRoleGroupCommand(Guid RoleGroupId, List<Guid> RoleIds) : IRequest<Result<RoleGroupDto>>;
