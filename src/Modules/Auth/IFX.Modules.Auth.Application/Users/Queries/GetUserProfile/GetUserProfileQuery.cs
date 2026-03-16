using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Queries.GetUserProfile;

public record GetUserProfileQuery(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
