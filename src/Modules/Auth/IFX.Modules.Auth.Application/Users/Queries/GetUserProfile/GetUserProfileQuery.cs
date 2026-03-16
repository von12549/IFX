using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserProfile;

public record GetUserProfileQuery(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
