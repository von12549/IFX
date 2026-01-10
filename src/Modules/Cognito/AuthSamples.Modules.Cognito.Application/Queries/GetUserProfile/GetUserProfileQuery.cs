using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Queries.GetUserProfile;

public record GetUserProfileQuery(string Subject) : IRequest<Result<UserProfileDto>>;
