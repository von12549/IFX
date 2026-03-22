using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveDepartmentFromUser;

public record RemoveDepartmentFromUserCommand(Guid UserId, Guid DepartmentId) : IRequest<Result<bool>>;
