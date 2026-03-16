using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.VerifyEmail;

public record VerifyEmailCommand(
    Guid UserIdentityId,
    string? Token,
    string? Code,
    string? IpAddress) : IRequest<Result<VerifyEmailResponse>>;
