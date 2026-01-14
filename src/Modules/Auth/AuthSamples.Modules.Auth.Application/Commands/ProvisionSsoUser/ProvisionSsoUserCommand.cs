using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Domain.Enums;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.ProvisionSsoUser;

public record ProvisionSsoUserCommand(
    Guid IdpId,
    string Issuer,
    string Subject,
    IdpType IdpType,
    string? Email,
    string? FirstName,
    string? LastName,
    bool EmailVerified,
    string? IpAddress) : IRequest<Result<ProvisionSsoUserResponse>>;
