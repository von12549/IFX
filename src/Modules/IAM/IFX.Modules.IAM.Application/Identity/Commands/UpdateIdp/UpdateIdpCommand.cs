using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Domain.Identity;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Commands.UpdateIdp;

public record UpdateIdpCommand(
    Guid IdpId,
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
    int ClockSkewSeconds) : ICommand<Result<IdpDto>, IamTransactionOwner>;
