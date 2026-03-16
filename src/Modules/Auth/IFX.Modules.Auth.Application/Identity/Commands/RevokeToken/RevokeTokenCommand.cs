using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.RevokeToken;

public record RevokeTokenCommand(
    string RefreshToken,
    string? Email = null,
    string? IpAddress = null) : IRequest<Result<bool>>;
