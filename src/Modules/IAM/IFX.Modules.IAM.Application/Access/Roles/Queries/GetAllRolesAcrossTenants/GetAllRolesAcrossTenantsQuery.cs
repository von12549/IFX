using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Queries.GetAllRolesAcrossTenants;

public record GetAllRolesAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<RoleDto>>>;
