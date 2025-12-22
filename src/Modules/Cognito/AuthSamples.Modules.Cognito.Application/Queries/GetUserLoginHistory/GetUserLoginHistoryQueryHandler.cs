using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Queries.GetUserLoginHistory;

public class GetUserLoginHistoryQueryHandler : IRequestHandler<GetUserLoginHistoryQuery, Result<PagedResult<LoginEventDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetUserLoginHistoryQueryHandler> _logger;

    public GetUserLoginHistoryQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<GetUserLoginHistoryQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<PagedResult<LoginEventDto>>> Handle(
        GetUserLoginHistoryQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByCognitoUserIdAsync(request.CognitoUserId, cancellationToken);
            if (user == null)
            {
                return Result<PagedResult<LoginEventDto>>.Failure("User not found");
            }

            var loginEvents = await _unitOfWork.LoginEvents.GetUserLoginHistoryAsync(
                user.Id,
                request.PageNumber,
                request.PageSize,
                cancellationToken);

            var totalCount = await _unitOfWork.LoginEvents.GetUserLoginCountAsync(
                user.Id,
                cancellationToken);

            var loginEventDtos = _mapper.Map<IEnumerable<LoginEventDto>>(loginEvents);

            var pagedResult = new PagedResult<LoginEventDto>
            {
                Items = loginEventDtos,
                TotalCount = totalCount,
                PageNumber = request.PageNumber,
                PageSize = request.PageSize
            };

            return Result<PagedResult<LoginEventDto>>.Success(pagedResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving login history for user {CognitoUserId}", request.CognitoUserId);
            return Result<PagedResult<LoginEventDto>>.Failure("An error occurred while retrieving login history");
        }
    }
}
