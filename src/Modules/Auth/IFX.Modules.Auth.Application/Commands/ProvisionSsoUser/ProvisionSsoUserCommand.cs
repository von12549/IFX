using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Domain.Enums;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.ProvisionSsoUser;

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
