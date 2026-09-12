using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Users.Queries.GetUserLoginHistory;

public record GetUserLoginHistoryQuery(
    string Issuer,
    string Subject,
    int PageNumber = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<LoginEventDto>>>;
