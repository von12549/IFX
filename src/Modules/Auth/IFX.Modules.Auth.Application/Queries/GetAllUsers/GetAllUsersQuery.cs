using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Queries.GetAllUsers;

public record GetAllUsersQuery(
    int PageNumber = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<UserProfileDto>>>;
