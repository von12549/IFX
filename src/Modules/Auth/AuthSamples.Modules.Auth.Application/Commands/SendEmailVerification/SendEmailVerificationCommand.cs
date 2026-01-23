using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.SendEmailVerification;

public record SendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<EmailVerificationTokenInfo>>;
