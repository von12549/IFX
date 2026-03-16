using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserActivityLog;

public class GetUserActivityLogQueryHandler : IRequestHandler<GetUserActivityLogQuery, Result<PagedResult<UserActivityDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetUserActivityLogQueryHandler> _logger;

    public GetUserActivityLogQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<GetUserActivityLogQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<PagedResult<UserActivityDto>>> Handle(
        GetUserActivityLogQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<PagedResult<UserActivityDto>>.Failure("User not found");
            }

            var activities = await _unitOfWork.UserActivityLogs.GetUserActivitiesAsync(
                user.Id,
                request.PageNumber,
                request.PageSize,
                cancellationToken);

            var totalCount = await _unitOfWork.UserActivityLogs.GetUserActivityCountAsync(
                user.Id,
                cancellationToken);

            var activityDtos = _mapper.Map<IEnumerable<UserActivityDto>>(activities);

            var pagedResult = new PagedResult<UserActivityDto>
            {
                Items = activityDtos,
                TotalCount = totalCount,
                PageNumber = request.PageNumber,
                PageSize = request.PageSize
            };

            return Result<PagedResult<UserActivityDto>>.Success(pagedResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving activity log for user {Issuer}/{Subject}", request.Issuer, request.Subject);
            return Result<PagedResult<UserActivityDto>>.Failure("An error occurred while retrieving activity log");
        }
    }
}
