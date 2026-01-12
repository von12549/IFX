using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetUserActivityLog;

public record GetUserActivityLogQuery(
    string Subject,
    int PageNumber = 1,
    int PageSize = 50) : IRequest<Result<PagedResult<UserActivityDto>>>;
