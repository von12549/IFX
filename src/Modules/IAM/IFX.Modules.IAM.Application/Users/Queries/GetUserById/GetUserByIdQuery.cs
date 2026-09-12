using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Queries.GetUserById;

public record GetUserByIdQuery(Guid UserId) : IRequest<Result<UserProfileDto>>;
