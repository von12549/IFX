using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Roles.Queries.GetAllRoles;

public class GetAllRolesQueryHandler : IRequestHandler<GetAllRolesQuery, Result<List<RoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetAllRolesQueryHandler> _logger;

    public GetAllRolesQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<GetAllRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<RoleDto>>> Handle(GetAllRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (!_currentUser.TenantId.HasValue)
                return Result<List<RoleDto>>.Success([]);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "role", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var roles = await _unitOfWork.Roles.GetByTenantIdAsync(_currentUser.TenantId.Value, cancellationToken);
            var roleDtos = _mapper.Map<List<RoleDto>>(roles);
            _logger.LogInformation("Retrieved {Count} roles", roleDtos.Count);
            return Result<List<RoleDto>>.Success(roleDtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles");
            return Result<List<RoleDto>>.Failure("An error occurred while retrieving roles");
        }
    }
}
