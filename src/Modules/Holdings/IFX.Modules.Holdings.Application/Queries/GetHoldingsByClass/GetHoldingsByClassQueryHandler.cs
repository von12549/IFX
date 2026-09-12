using IFX.Modules.Holdings.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using IFX.Modules.Holdings.Application.Common.Authorization;
using IFX.Modules.Holdings.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingsByClass;

public class GetHoldingsByClassQueryHandler : IRequestHandler<GetHoldingsByClassQuery, Result<IReadOnlyList<HoldingSummaryDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetHoldingsByClassQueryHandler> _logger;

    public GetHoldingsByClassQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<GetHoldingsByClassQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<IReadOnlyList<HoldingSummaryDto>>> Handle(GetHoldingsByClassQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "holding", "list", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<HoldingSummaryDto>>.Failure("Tenant context required.");

            var holdings = await _unitOfWork.Holdings.GetByClassAsync(_currentUser.TenantId.Value, request.ClassId, cancellationToken);
            var dtos = _mapper.Map<IReadOnlyList<HoldingSummaryDto>>(holdings);
            return Result<IReadOnlyList<HoldingSummaryDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting holdings for class {ClassId}", request.ClassId);
            return Result<IReadOnlyList<HoldingSummaryDto>>.Failure("An error occurred.");
        }
    }
}
