using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Domain.Identity;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Commands.ProvisionSsoUser;

public record ProvisionSsoUserCommand(
    Guid IdpId,
    string Issuer,
    string Subject,
    IdpType IdpType,
    string? Email,
    string? FirstName,
    string? LastName,
    bool EmailVerified,
    string? IpAddress) : ICommand<Result<ProvisionSsoUserResponse>, AuthTransactionOwner>;
