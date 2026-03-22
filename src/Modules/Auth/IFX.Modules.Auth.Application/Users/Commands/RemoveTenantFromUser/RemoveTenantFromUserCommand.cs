using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveTenantFromUser;

public record RemoveTenantFromUserCommand(Guid UserId, Guid TenantId) : IRequest<Result<bool>>;
