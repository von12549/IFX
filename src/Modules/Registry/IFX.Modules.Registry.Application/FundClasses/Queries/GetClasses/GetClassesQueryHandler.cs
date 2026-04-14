using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.FundClasses.Queries.GetClasses;

public class GetClassesQueryHandler : IRequestHandler<GetClassesQuery, Result<List<FundClassDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetClassesQueryHandler> _logger;

    public GetClassesQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetClassesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<FundClassDto>>> Handle(GetClassesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<List<FundClassDto>>.Success(new List<FundClassDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fundclass", "list",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var fundClasses = await _unitOfWork.FundClasses.GetByFundIdAsync(request.FundId, tenantId.Value, cancellationToken);
            return Result<List<FundClassDto>>.Success(_mapper.Map<List<FundClassDto>>(fundClasses));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving fund classes for fund {FundId}", request.FundId);
            return Result<List<FundClassDto>>.Failure("An error occurred while retrieving fund classes.");
        }
    }
}
