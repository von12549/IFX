using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.ResendEmailVerification;

public record ResendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<EmailVerificationTokenInfo>>;
