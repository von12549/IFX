using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.DeleteDepartment;

public record DeleteDepartmentCommand(Guid DepartmentId) : IRequest<Result<bool>>;
