using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.UpdateUserProfile;

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
            // Get user by CognitoUserId
            var user = await _unitOfWork.Users.GetByCognitoUserIdAsync(request.CognitoUserId, cancellationToken);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found");
            }

            // Track which fields were updated for activity log
            var updatedFields = new List<string>();
            if (request.Username != null) updatedFields.Add("Username");
            if (request.FirstName != null) updatedFields.Add("FirstName");
            if (request.LastName != null) updatedFields.Add("LastName");
            if (request.PhoneNumber != null) updatedFields.Add("PhoneNumber");

            // Update user profile via domain method
            user.UpdateProfile(
                request.Username,
                request.FirstName,
                request.LastName,
                request.PhoneNumber);

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
                "User profile updated for {CognitoUserId}. Updated fields: {Fields}",
                request.CognitoUserId,
                string.Join(", ", updatedFields));

            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UserProfileDto>.Success(userProfile);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating profile for user {CognitoUserId}", request.CognitoUserId);
            return Result<UserProfileDto>.Failure("An error occurred while updating profile");
        }
    }
}
