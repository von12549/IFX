using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Funds.Queries.GetFunds;

public class GetFundsQueryHandler : IRequestHandler<GetFundsQuery, Result<List<FundDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetFundsQueryHandler> _logger;

    public GetFundsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetFundsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<FundDto>>> Handle(GetFundsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<List<FundDto>>.Success(new List<FundDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fund", "list",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var funds = await _unitOfWork.Funds.GetByTenantIdAsync(tenantId.Value, cancellationToken);
            return Result<List<FundDto>>.Success(_mapper.Map<List<FundDto>>(funds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving funds");
            return Result<List<FundDto>>.Failure("An error occurred while retrieving funds.");
        }
    }
}
