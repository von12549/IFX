using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Queries.GetAllDepartments;

public record GetAllDepartmentsQuery : IRequest<Result<List<DepartmentDto>>>;
