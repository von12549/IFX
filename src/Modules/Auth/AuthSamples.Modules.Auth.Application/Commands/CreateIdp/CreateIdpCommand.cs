using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Domain.Enums;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.CreateIdp;

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
