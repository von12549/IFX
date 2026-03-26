using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetDepartmentById;

public record GetDepartmentByIdQuery(Guid DepartmentId) : IRequest<Result<DepartmentDto>>;
