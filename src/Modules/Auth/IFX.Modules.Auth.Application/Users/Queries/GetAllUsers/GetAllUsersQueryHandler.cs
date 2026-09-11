using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetAllUsers;

public class GetAllUsersQueryHandler : IRequestHandler<GetAllUsersQuery, Result<PagedResult<UserProfileDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetAllUsersQueryHandler> _logger;

    public GetAllUsersQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetAllUsersQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<PagedResult<UserProfileDto>>> Handle(
        GetAllUsersQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (!_currentUser.TenantId.HasValue)
                return Result<PagedResult<UserProfileDto>>.Success(new PagedResult<UserProfileDto>
                {
                    Items = [],
                    TotalCount = 0,
                    PageNumber = request.PageNumber,
                    PageSize = request.PageSize
                });

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "user", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var (users, totalCount) = await _unitOfWork.Users.GetAllUsersByTenantAsync(
                _currentUser.TenantId.Value,
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
