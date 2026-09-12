using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Queries.GetUserProfile;

public record GetUserProfileQuery(string Issuer, string Subject) : IRequest<Result<UserProfileDto>>;
