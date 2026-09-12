using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Commands.UpdateUserProfile;

public record UpdateUserProfileCommand(
    string Issuer,
    string Subject,
    string? Username = null,
    string? FirstName = null,
    string? LastName = null,
    string? PhoneNumber = null,
    string? Email = null,
    string? IpAddress = null,
    Guid? PrimaryTenantId = null) : ICommand<Result<UpdateUserProfileResponse>, IamTransactionOwner>;

public record UpdateUserProfileResponse(
    UserProfileDto Profile,
    bool EmailChanged,
    bool RequiresEmailVerification,
    Guid? UserIdentityId);
