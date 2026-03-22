using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Queries.GetAllUsers;

public record GetAllUsersQuery(
    int PageNumber = 1,
    int PageSize = 50,
    Guid? TenantId = null) : IRequest<Result<PagedResult<UserProfileDto>>>;
