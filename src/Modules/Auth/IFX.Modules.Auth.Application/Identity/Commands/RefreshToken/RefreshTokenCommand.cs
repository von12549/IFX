using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.RefreshToken;

public record RefreshTokenCommand(
    string RefreshToken,
    string Username,
    string? IpAddress = null) : IRequest<Result<RefreshTokenResponse>>;
