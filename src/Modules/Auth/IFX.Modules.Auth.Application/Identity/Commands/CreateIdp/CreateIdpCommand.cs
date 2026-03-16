using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Domain.Identity;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.CreateIdp;

public record CreateIdpCommand(
    string Name,
    string Issuer,
    string Authority,
    string Description,
    string LoginUrl,
    IdpType IdpType,
    bool IsPrimary,
    bool Enabled,
    bool AutoProvisionEnabled,
    string ExpectedAudiences,
    string AllowedAlgs,
    string RequiredScopes,
    string ClaimMapping,
    int ClockSkewSeconds) : IRequest<Result<IdpDto>>;
