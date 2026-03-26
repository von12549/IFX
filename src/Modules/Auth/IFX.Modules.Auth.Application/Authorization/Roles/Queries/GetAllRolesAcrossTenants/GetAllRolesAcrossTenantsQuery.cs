using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetAllRolesAcrossTenants;

public record GetAllRolesAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<RoleDto>>>;
