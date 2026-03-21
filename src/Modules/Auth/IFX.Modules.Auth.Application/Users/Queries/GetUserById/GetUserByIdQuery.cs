using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserById;

public record GetUserByIdQuery(Guid UserId) : IRequest<Result<UserProfileDto>>;
