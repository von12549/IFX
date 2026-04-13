using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Products.Commands.UpdateProduct;

public class UpdateProductCommandHandler : IRequestHandler<UpdateProductCommand, Result<ProductDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateProductCommandHandler> _logger;

    public UpdateProductCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<UpdateProductCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<ProductDto>> Handle(UpdateProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<ProductDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "product", "update",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var product = await _unitOfWork.Products.GetByIdAsync(request.ProductId, tenantId.Value, cancellationToken);
            if (product == null)
                return Result<ProductDto>.Failure("Product not found.");

            product.Update(
                request.ProductName,
                request.ApirCode,
                request.Isin,
                request.RegulatorSchemeNumber,
                request.PdsReference,
                request.IssuerName,
                request.WindUpDate);

            product.UpdatedBy = _currentUser.UserId;
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Product updated: {ProductId}", product.Id);
            return Result<ProductDto>.Success(_mapper.Map<ProductDto>(product));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating product {ProductId}", request.ProductId);
            return Result<ProductDto>.Failure("An error occurred while updating the product.");
        }
    }
}
