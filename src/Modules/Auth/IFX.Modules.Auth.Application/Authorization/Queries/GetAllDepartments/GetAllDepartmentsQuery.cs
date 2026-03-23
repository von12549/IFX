using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllDepartments;

public record GetAllDepartmentsQuery : IRequest<Result<List<DepartmentDto>>>;
