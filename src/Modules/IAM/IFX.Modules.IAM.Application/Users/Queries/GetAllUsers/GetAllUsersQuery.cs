using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Queries.GetAllUsers;

public record GetAllUsersQuery(
    int PageNumber = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<UserProfileDto>>>;
