using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Queries.GetAllRoleGroupsAcrossTenants;

public record GetAllRoleGroupsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<RoleGroupDto>>>;
