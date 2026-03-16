using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserActivityLog;

public record GetUserActivityLogQuery(
    string Issuer,
    string Subject,
    int PageNumber = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<UserActivityDto>>>;
