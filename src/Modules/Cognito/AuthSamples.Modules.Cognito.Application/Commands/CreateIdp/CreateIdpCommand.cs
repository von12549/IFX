using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.CreateIdp;

public record CreateIdpCommand(
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
