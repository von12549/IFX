using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetAllUsers;

public class GetAllUsersQueryHandler : IRequestHandler<GetAllUsersQuery, Result<PagedResult<UserProfileDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetAllUsersQueryHandler> _logger;

    public GetAllUsersQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<GetAllUsersQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<PagedResult<UserProfileDto>>> Handle(
        GetAllUsersQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (!request.TenantId.HasValue)
                return Result<PagedResult<UserProfileDto>>.Success(new PagedResult<UserProfileDto>
                {
                    Items = [],
                    TotalCount = 0,
                    PageNumber = request.PageNumber,
                    PageSize = request.PageSize
                });

            var (users, totalCount) = await _unitOfWork.Users.GetAllUsersByTenantAsync(
                request.TenantId.Value,
                request.PageNumber,
                request.PageSize,
                cancellationToken);

            var userProfileDtos = _mapper.Map<IEnumerable<UserProfileDto>>(users);

            var pagedResult = new PagedResult<UserProfileDto>
            {
                Items = userProfileDtos,
                TotalCount = totalCount,
                PageNumber = request.PageNumber,
                PageSize = request.PageSize
            };

            _logger.LogInformation(
                "Retrieved {Count} users (page {PageNumber} of {TotalPages})",
                userProfileDtos.Count(),
                request.PageNumber,
                pagedResult.TotalPages);

            return Result<PagedResult<UserProfileDto>>.Success(pagedResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users list");
            return Result<PagedResult<UserProfileDto>>.Failure("An error occurred while retrieving users");
        }
    }
}
