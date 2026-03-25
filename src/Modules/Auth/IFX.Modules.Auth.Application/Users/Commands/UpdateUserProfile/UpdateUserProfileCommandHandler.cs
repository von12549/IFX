using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
// ActivityType is in IFX.Modules.Auth.Domain.Users (already added above)
// EmailAddress, Subject are in IFX.Modules.Auth.Domain.Users (already added above)
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.UpdateUserProfile;

public class UpdateUserProfileCommandHandler : IRequestHandler<UpdateUserProfileCommand, Result<UpdateUserProfileResponse>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateUserProfileCommandHandler> _logger;

    public UpdateUserProfileCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<UpdateUserProfileCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UpdateUserProfileResponse>> Handle(
        UpdateUserProfileCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get user by Issuer and Subject
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<UpdateUserProfileResponse>.Failure("User not found");
            }

            // Get the specific UserIdentity for this Issuer+Subject
            var identity = user.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);
            if (identity == null)
            {
                return Result<UpdateUserProfileResponse>.Failure("User identity not found");
            }

            // Track which fields were updated for activity log
            var updatedFields = new List<string>();
            if (request.FirstName != null) updatedFields.Add("FirstName");
            if (request.LastName != null) updatedFields.Add("LastName");
            if (request.PhoneNumber != null) updatedFields.Add("PhoneNumber");

            // Handle email change
            var emailChanged = false;
            var requiresEmailVerification = false;

            if (!string.IsNullOrEmpty(request.Email))
            {
                var newEmail = EmailAddress.Create(request.Email);
                emailChanged = identity.UpdateEmail(newEmail);

                if (emailChanged)
                {
                    updatedFields.Add("Email");
                    requiresEmailVerification = true;

                    _logger.LogInformation(
                        "Email changed for user {UserId}: {OldEmail} -> {NewEmail}. Verification required.",
                        user.Id, identity.Email.Value, request.Email);

                    // Create email changed activity log
                    var emailChangedLog = UserActivityLog.Create(
                        user.Id,
                        ActivityType.EmailChanged,
                        $"Email changed to {request.Email}. Verification required.",
                        request.IpAddress);

                    await _unitOfWork.UserActivityLogs.AddAsync(emailChangedLog, cancellationToken);
                }
            }

            // Update UserIdentity profile
            identity.UpdateProfile(
                request.FirstName,
                request.LastName,
                request.PhoneNumber);

            // Update User DisplayName if name changed
            if (request.FirstName != null || request.LastName != null)
            {
                var newDisplayName = $"{identity.FirstName} {identity.LastName}";
                if (user.DisplayName != newDisplayName)
                {
                    user.UpdateDisplayName(newDisplayName);
                }
            }

            // Update PrimaryTenant if requested
            if (request.PrimaryTenantId.HasValue)
            {
                if (!user.Tenants.Any(t => t.Id == request.PrimaryTenantId.Value))
                    return Result<UpdateUserProfileResponse>.Failure("Tenant is not assigned to this user");

                user.SetPrimaryTenant(request.PrimaryTenantId.Value);
                updatedFields.Add("PrimaryTenantId");
            }

            await _unitOfWork.UserIdentities.UpdateAsync(identity, cancellationToken);
            await _unitOfWork.Users.UpdateAsync(user, cancellationToken);

            // Create profile update activity log
            if (updatedFields.Count > 0)
            {
                var activityLog = UserActivityLog.Create(
                    user.Id,
                    ActivityType.ProfileUpdate,
                    $"Profile updated: {string.Join(", ", updatedFields)}",
                    request.IpAddress,
                    $"{{\"updatedFields\": [\"{string.Join("\", \"", updatedFields)}\"]}}");

                await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "User profile updated for {Issuer}/{Subject}. Updated fields: {Fields}",
                request.Issuer,
                request.Subject,
                string.Join(", ", updatedFields));

            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UpdateUserProfileResponse>.Success(new UpdateUserProfileResponse(
                Profile: userProfile,
                EmailChanged: emailChanged,
                RequiresEmailVerification: requiresEmailVerification,
                UserIdentityId: requiresEmailVerification ? identity.Id : null));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user {Issuer}/{Subject}", request.Issuer, request.Subject);
            return Result<UpdateUserProfileResponse>.Failure("An error occurred while updating profile");
        }
    }
}
