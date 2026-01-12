using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateIdp;

public record UpdateIdpCommand(
    Guid IdpId,
    string Name,
    string Issuer,
    string Authority,
    string Description,
    string LoginUrl,
    bool Enabled,
    bool AutoProvisionEnabled,
    string ExpectedAudiences,
    string AllowedAlgs,
    string RequiredScopes,
    string ClaimMapping,
    int ClockSkewSeconds) : IRequest<Result<IdpDto>>;
