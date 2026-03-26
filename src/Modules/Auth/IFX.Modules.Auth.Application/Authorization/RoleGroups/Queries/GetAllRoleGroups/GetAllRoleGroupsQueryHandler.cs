using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Queries.GetAllRoleGroups;

public class GetAllRoleGroupsQueryHandler : IRequestHandler<GetAllRoleGroupsQuery, Result<List<RoleGroupDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetAllRoleGroupsQueryHandler> _logger;

    public GetAllRoleGroupsQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<GetAllRoleGroupsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<RoleGroupDto>>> Handle(GetAllRoleGroupsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (!_currentUser.TenantId.HasValue)
                return Result<List<RoleGroupDto>>.Success([]);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "rolegroup", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var groups = await _unitOfWork.RoleGroups.GetByTenantIdAsync(_currentUser.TenantId.Value, cancellationToken);
            var dtos = _mapper.Map<List<RoleGroupDto>>(groups);
            _logger.LogInformation("Retrieved {Count} role groups", dtos.Count);
            return Result<List<RoleGroupDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving role groups");
            return Result<List<RoleGroupDto>>.Failure("An error occurred while retrieving role groups");
        }
    }
}
