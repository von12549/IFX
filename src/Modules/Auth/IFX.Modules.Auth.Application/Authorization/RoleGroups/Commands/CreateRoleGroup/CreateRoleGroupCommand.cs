using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.CreateRoleGroup;

public record CreateRoleGroupCommand(string Name, string Description, Guid TenantId) : IRequest<Result<RoleGroupDto>>;
