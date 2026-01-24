using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.VerifyEmail;

public record VerifyEmailCommand(
    Guid UserIdentityId,
    string? Token,
    string? Code,
    string? IpAddress) : IRequest<Result<VerifyEmailResponse>>;
