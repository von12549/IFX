using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.CreateDepartment;

public record CreateDepartmentCommand(string Name, string Description, Guid TenantId) : IRequest<Result<DepartmentDto>>;
