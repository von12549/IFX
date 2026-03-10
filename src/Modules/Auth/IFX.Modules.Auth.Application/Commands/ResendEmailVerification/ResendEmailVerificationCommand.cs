using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.ResendEmailVerification;

public record ResendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<EmailVerificationTokenInfo>>;
