using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetAllDepartmentsAcrossTenants;

public record GetAllDepartmentsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<DepartmentDto>>>;
