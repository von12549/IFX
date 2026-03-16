using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Queries.GetUserLoginHistory;

public record GetUserLoginHistoryQuery(
    string Issuer,
    string Subject,
    int PageNumber = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<LoginEventDto>>>;
