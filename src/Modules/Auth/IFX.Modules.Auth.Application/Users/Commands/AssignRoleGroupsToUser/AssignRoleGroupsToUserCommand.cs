using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignRoleGroupsToUser;

public record AssignRoleGroupsToUserCommand(Guid UserId, List<Guid> RoleGroupIds) : IRequest<Result<bool>>;
