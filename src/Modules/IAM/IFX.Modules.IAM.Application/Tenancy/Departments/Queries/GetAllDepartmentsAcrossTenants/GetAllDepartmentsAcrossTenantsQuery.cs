using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Queries.GetAllDepartmentsAcrossTenants;

public record GetAllDepartmentsAcrossTenantsQuery : IRequest<Result<CrossTenantResultDto<DepartmentDto>>>;
