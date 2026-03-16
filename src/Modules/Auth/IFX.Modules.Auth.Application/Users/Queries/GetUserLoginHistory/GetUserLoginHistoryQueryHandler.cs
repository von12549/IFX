using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Queries.GetUserLoginHistory;

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
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
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
            _logger.LogError(ex, "Error retrieving login history for user {Issuer}/{Subject}", request.Issuer, request.Subject);
            return Result<PagedResult<LoginEventDto>>.Failure("An error occurred while retrieving login history");
        }
    }
}
