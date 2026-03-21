using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleFromUser;

public record RemoveRoleFromUserCommand(Guid UserId, Guid RoleId) : IRequest<Result<bool>>;
