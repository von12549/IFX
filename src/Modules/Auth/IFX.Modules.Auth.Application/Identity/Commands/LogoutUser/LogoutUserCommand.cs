using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.LogoutUser;

public record LogoutUserCommand(
    string Issuer,
    string Subject,
    string AccessToken,
    string IpAddress) : IRequest<Result<bool>>;
