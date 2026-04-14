using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Products.Commands.DeleteProduct;

public class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<DeleteProductCommandHandler> _logger;

    public DeleteProductCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<DeleteProductCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteProductCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<bool>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "product", "delete",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var product = await _unitOfWork.Products.GetByIdAsync(request.ProductId, tenantId.Value, cancellationToken);
            if (product == null)
                return Result<bool>.Failure("Product not found.");

            product.Close();
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(
                new ProductStatusChangedEvent(product.Id, product.TenantId, product.Status.ToString()),
                cancellationToken);

            _logger.LogInformation("Product closed: {ProductId}", product.Id);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error closing product {ProductId}", request.ProductId);
            return Result<bool>.Failure("An error occurred while closing the product.");
        }
    }
}
