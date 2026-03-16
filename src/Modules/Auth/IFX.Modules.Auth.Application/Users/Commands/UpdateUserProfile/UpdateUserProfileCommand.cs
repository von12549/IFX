using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Commands.UpdateUserProfile;

public record UpdateUserProfileCommand(
    string Issuer,
    string Subject,
    string? Username = null,
    string? FirstName = null,
    string? LastName = null,
    string? PhoneNumber = null,
    string? Email = null,
    string? IpAddress = null) : IRequest<Result<UpdateUserProfileResponse>>;

public record UpdateUserProfileResponse(
    UserProfileDto Profile,
    bool EmailChanged,
    bool RequiresEmailVerification,
    Guid? UserIdentityId);
