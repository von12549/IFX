using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using IFX.Modules.Holdings.Application.Common.Authorization;
using IFX.Modules.Holdings.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingById;

public class GetHoldingByIdQueryHandler : IRequestHandler<GetHoldingByIdQuery, Result<HoldingSummaryDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetHoldingByIdQueryHandler> _logger;

    public GetHoldingByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<GetHoldingByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<HoldingSummaryDto>> Handle(GetHoldingByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "holding", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            var holding = await _unitOfWork.Holdings.GetByIdAsync(request.HoldingId, cancellationToken);
            if (holding == null)
                return Result<HoldingSummaryDto>.Failure($"Holding {request.HoldingId} not found.");

            var dto = _mapper.Map<HoldingSummaryDto>(holding);
            return Result<HoldingSummaryDto>.Success(dto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting holding {HoldingId}", request.HoldingId);
            return Result<HoldingSummaryDto>.Failure("An error occurred.");
        }
    }
}
