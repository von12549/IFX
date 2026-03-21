using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Commands.UpdateRoleGroup;

public record UpdateRoleGroupCommand(Guid RoleGroupId, string Name, string Description) : IRequest<Result<RoleGroupDto>>;
