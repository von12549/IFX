using AuthSamples.Modules.Auth.Application.Common;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.RevokeToken;

public record RevokeTokenCommand(
    string RefreshToken,
    string? Email = null,
    string? IpAddress = null) : IRequest<Result<bool>>;
