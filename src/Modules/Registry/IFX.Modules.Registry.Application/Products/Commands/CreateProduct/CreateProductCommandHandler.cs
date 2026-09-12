using IFX.Modules.Registry.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Products.DTOs;
using IFX.Modules.Registry.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.Products.Commands.CreateProduct;
public class CreateProductCommandHandler : IRequestHandler<CreateProductCommand, Result<ProductDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateProductCommandHandler> _logger;
    public CreateProductCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreateProductCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<ProductDto>> Handle(CreateProductCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<ProductDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("product", "create", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            if (await _unitOfWork.Products.CodeExistsAsync(request.ProductCode, tenantId.Value, cancellationToken))
                return Result<ProductDto>.Failure($"Product code '{request.ProductCode}' already exists in this tenant.");
            var product = Product.Create(tenantId.Value, request.ProductCode, request.ProductName, request.ProductType, request.BaseCurrency, request.InceptionDate, request.ApirCode, request.Isin, request.RegulatorSchemeNumber, request.PdsReference, request.IssuerName);
            product.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Products.AddAsync(product, cancellationToken);
            _logger.LogInformation("Product created: {ProductCode} in tenant {TenantId}", product.ProductCode, product.TenantId);
            return Result<ProductDto>.Success(_mapper.Map<ProductDto>(product));
        }
    }
}
