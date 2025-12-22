using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Queries.GetUserLoginHistory;

public record GetUserLoginHistoryQuery(
    string CognitoUserId,
    int PageNumber = 1,
    int PageSize = 20) : IRequest<Result<PagedResult<LoginEventDto>>>;
