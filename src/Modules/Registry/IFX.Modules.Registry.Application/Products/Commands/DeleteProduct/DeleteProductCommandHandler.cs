using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.Products.Commands.DeleteProduct;
public class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<DeleteProductCommandHandler> _logger;
    public DeleteProductCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<DeleteProductCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteProductCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<bool>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("product", "delete", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            var product = await _unitOfWork.Products.GetByIdAsync(request.ProductId, tenantId.Value, cancellationToken);
            if (product == null)
                return Result<bool>.Failure("Product not found.");
            product.Close();
            _logger.LogInformation("Product closed: {ProductId}", product.Id);
            return Result<bool>.Success(true);
        }
    }
}
