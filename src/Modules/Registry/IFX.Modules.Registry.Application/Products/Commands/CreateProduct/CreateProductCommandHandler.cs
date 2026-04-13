using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.DTOs;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Products.Commands.CreateProduct;

public class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, Result<ProductDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateProductCommandHandler> _logger;

    public CreateProductCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<CreateProductCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<ProductDto>> Handle(CreateProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<ProductDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "product", "create",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            if (await _unitOfWork.Products.CodeExistsAsync(request.ProductCode, tenantId.Value, cancellationToken))
                return Result<ProductDto>.Failure($"Product code '{request.ProductCode}' already exists in this tenant.");

            var product = Product.Create(
                tenantId.Value,
                request.ProductCode,
                request.ProductName,
                request.ProductType,
                request.BaseCurrency,
                request.InceptionDate,
                request.ApirCode,
                request.Isin,
                request.RegulatorSchemeNumber,
                request.PdsReference,
                request.IssuerName);

            product.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Products.AddAsync(product, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new ProductCreatedEvent(product.Id, product.TenantId, product.ProductCode, product.ProductName), cancellationToken);

            _logger.LogInformation("Product created: {ProductCode} in tenant {TenantId}", product.ProductCode, product.TenantId);
            return Result<ProductDto>.Success(_mapper.Map<ProductDto>(product));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating product {ProductCode}", request.ProductCode);
            return Result<ProductDto>.Failure("An error occurred while creating the product.");
        }
    }
}
