using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Commands.UpdateUserProfile;

public record UpdateUserProfileCommand(
    string CognitoUserId,
    string? Username = null,
    string? FirstName = null,
    string? LastName = null,
    string? PhoneNumber = null) : IRequest<Result<UserProfileDto>>;
