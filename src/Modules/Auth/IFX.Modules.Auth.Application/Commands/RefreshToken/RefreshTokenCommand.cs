using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.RefreshToken;

public record RefreshTokenCommand(
    string RefreshToken,
    string Username,
    string? IpAddress = null) : IRequest<Result<RefreshTokenResponse>>;
