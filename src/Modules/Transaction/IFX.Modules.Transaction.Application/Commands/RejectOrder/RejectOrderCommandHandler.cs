using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Commands.RejectOrder;

public class RejectOrderCommandHandler : IRequestHandler<RejectOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<RejectOrderCommandHandler> _logger;

    public RejectOrderCommandHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus, ILogger<RejectOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _eventBus = eventBus; _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(RejectOrderCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");

            var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(request.OrderId, cancellationToken);
            if (order == null || order.TenantId != _currentUser.TenantId.Value)
                return Result<OrderDto>.Failure("Order not found.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "order", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            order.Reject(request.Reason);
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new OrderRejectedEvent(order.Id, order.TenantId, request.Reason), cancellationToken);

            _logger.LogInformation("Order rejected: {OrderId} Reason={Reason}", order.Id, request.Reason);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (InvalidOperationException ex)
        {
            return Result<OrderDto>.Failure(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting order {OrderId}", request.OrderId);
            return Result<OrderDto>.Failure("An error occurred while rejecting the order.");
        }
    }
}
