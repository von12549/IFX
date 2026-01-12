using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetUserLoginHistory;

public record GetUserLoginHistoryQuery(
    string Subject,
    int PageNumber = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<LoginEventDto>>>;
