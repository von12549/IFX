using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.RefreshToken;

public record RefreshTokenCommand(
    string RefreshToken,
    string Username,
    string? IpAddress = null) : IRequest<Result<RefreshTokenResponse>>;
