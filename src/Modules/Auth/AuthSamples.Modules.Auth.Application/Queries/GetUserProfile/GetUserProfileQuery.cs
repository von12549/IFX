using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetUserProfile;

public record GetUserProfileQuery(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
