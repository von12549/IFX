using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Queries.GetAllRoleGroupsAcrossTenants;

public record GetAllRoleGroupsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<RoleGroupDto>>>;
