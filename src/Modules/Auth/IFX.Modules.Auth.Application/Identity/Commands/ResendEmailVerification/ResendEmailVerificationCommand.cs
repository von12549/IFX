using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.ResendEmailVerification;

public record ResendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<EmailVerificationTokenInfo>>;
