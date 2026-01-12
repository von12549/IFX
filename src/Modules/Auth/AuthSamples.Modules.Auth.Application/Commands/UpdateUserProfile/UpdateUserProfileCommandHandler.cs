using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.Enums;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;

public class UpdateUserProfileCommandHandler : IRequestHandler<UpdateUserProfileCommand, Result<UserProfileDto>>
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

    public async Task<Result<UserProfileDto>> Handle(
        UpdateUserProfileCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get user by Issuer and Subject
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found");
            }

            // Get the specific UserIdentity for this Issuer+Subject
            var identity = user.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);
            if (identity == null)
            {
                return Result<UserProfileDto>.Failure("User identity not found");
            }

            // Track which fields were updated for activity log
            var updatedFields = new List<string>();
            if (request.FirstName != null) updatedFields.Add("FirstName");
            if (request.LastName != null) updatedFields.Add("LastName");
            if (request.PhoneNumber != null) updatedFields.Add("PhoneNumber");

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

            await _unitOfWork.UserIdentities.UpdateAsync(identity, cancellationToken);
            await _unitOfWork.Users.UpdateAsync(user, cancellationToken);

            // Create activity log
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.ProfileUpdate,
                $"Profile updated: {string.Join(", ", updatedFields)}",
                null,
                $"{{\"updatedFields\": [\"{string.Join("\", \"", updatedFields)}\"]}}");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "User profile updated for {Issuer}/{Subject}. Updated fields: {Fields}",
                request.Issuer,
                request.Subject,
                string.Join(", ", updatedFields));

            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UserProfileDto>.Success(userProfile);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user {Issuer}/{Subject}", request.Issuer, request.Subject);
            return Result<UserProfileDto>.Failure("An error occurred while updating profile");
        }
    }
}
