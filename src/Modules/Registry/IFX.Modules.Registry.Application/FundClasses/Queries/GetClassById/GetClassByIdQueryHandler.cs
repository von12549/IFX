using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.FundClasses.Queries.GetClassById;

public class GetClassByIdQueryHandler : IRequestHandler<GetClassByIdQuery, Result<FundClassDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetClassByIdQueryHandler> _logger;

    public GetClassByIdQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetClassByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<FundClassDto>> Handle(GetClassByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundClassDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fundclass", "read",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var fundClass = await _unitOfWork.FundClasses.GetByIdAsync(request.ClassId, tenantId.Value, cancellationToken);
            if (fundClass == null)
                return Result<FundClassDto>.Failure("Fund class not found.");

            if (fundClass.FundId != request.FundId)
                return Result<FundClassDto>.Failure("Fund class does not belong to the specified fund.");

            return Result<FundClassDto>.Success(_mapper.Map<FundClassDto>(fundClass));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving fund class {ClassId}", request.ClassId);
            return Result<FundClassDto>.Failure("An error occurred while retrieving the fund class.");
        }
    }
}
