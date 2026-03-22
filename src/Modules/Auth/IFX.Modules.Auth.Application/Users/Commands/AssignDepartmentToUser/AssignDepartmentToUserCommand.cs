using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignDepartmentToUser;

public record AssignDepartmentToUserCommand(Guid UserId, Guid DepartmentId) : IRequest<Result<bool>>;
