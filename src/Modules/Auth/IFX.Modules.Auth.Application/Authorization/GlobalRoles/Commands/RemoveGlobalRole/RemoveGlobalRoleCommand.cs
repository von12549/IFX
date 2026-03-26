using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.RemoveGlobalRole;

public record RemoveGlobalRoleCommand(Guid UserId, Guid GlobalRoleId) : IRequest<Result<bool>>;
