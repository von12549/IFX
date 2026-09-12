using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Queries.GetDepartmentById;

public record GetDepartmentByIdQuery(Guid DepartmentId) : IRequest<Result<DepartmentDto>>;
