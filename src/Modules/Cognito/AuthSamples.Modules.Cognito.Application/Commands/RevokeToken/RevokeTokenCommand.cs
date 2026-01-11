using AuthSamples.Modules.Cognito.Application.Common;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.RevokeToken;

public record RevokeTokenCommand(
    string RefreshToken,
    string? Email = null,
    string? IpAddress = null) : IRequest<Result<bool>>;
