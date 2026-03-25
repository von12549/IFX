using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.UpdateDepartment;

public record UpdateDepartmentCommand(Guid DepartmentId, string Name, string Description) : IRequest<Result<DepartmentDto>>;
