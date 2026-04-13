using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Products.Queries.GetProducts;

public class GetProductsQueryHandler : IRequestHandler<GetProductsQuery, Result<List<ProductDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetProductsQueryHandler> _logger;

    public GetProductsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetProductsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<ProductDto>>> Handle(GetProductsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<List<ProductDto>>.Success(new List<ProductDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "product", "list",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var products = await _unitOfWork.Products.GetByTenantIdAsync(tenantId.Value, cancellationToken);
            return Result<List<ProductDto>>.Success(_mapper.Map<List<ProductDto>>(products));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving products");
            return Result<List<ProductDto>>.Failure("An error occurred while retrieving products.");
        }
    }
}
