using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.RefreshToken;

public record RefreshTokenCommand(
    string RefreshToken,
    string Username,
    string? IpAddress = null) : IRequest<Result<RefreshTokenResponse>>;
