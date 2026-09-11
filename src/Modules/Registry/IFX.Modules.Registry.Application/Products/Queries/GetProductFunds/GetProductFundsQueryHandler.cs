using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Products.Queries.GetProductFunds;

public class GetProductFundsQueryHandler : IRequestHandler<GetProductFundsQuery, Result<List<FundDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetProductFundsQueryHandler> _logger;

    public GetProductFundsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetProductFundsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<FundDto>>> Handle(GetProductFundsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<List<FundDto>>.Success(new List<FundDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "product", "read",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var product = await _unitOfWork.Products.GetByIdAsync(request.ProductId, tenantId.Value, cancellationToken);
            if (product == null)
                return Result<List<FundDto>>.Failure("Product not found.");

            var funds = await _unitOfWork.Products.GetFundsByProductIdAsync(request.ProductId, tenantId.Value, cancellationToken);
            return Result<List<FundDto>>.Success(_mapper.Map<List<FundDto>>(funds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving funds for product {ProductId}", request.ProductId);
            return Result<List<FundDto>>.Failure("An error occurred while retrieving product funds.");
        }
    }
}
