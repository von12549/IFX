using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetDepartmentById;

public record GetDepartmentByIdQuery(Guid DepartmentId) : IRequest<Result<DepartmentDto>>;
