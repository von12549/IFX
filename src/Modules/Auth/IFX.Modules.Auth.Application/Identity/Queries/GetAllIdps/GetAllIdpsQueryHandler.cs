using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetAllIdps;

public class GetAllIdpsQueryHandler : IRequestHandler<GetAllIdpsQuery, Result<List<IdpDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetAllIdpsQueryHandler> _logger;

    public GetAllIdpsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetAllIdpsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<IdpDto>>> Handle(
        GetAllIdpsQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (!_currentUser.TenantId.HasValue)
                return Result<List<IdpDto>>.Success([]);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "idp", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var idps = await _unitOfWork.Idps.GetByTenantIdAsync(_currentUser.TenantId.Value, cancellationToken);
            var idpDtos = _mapper.Map<List<IdpDto>>(idps);

            _logger.LogInformation("Retrieved {Count} Identity Providers", idpDtos.Count);

            return Result<List<IdpDto>>.Success(idpDtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving Identity Providers");
            return Result<List<IdpDto>>.Failure("An error occurred while retrieving Identity Providers");
        }
    }
}
