using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;

public record UpdateUserProfileCommand(
    string Subject,
    string? Username = null,
    string? FirstName = null,
    string? LastName = null,
    string? PhoneNumber = null) : IRequest<Result<UserProfileDto>>;
