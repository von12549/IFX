using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.ValueObjects;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Commands.ConfirmOrder;

public class ConfirmOrderCommandHandler : IRequestHandler<ConfirmOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<ConfirmOrderCommandHandler> _logger;

    public ConfirmOrderCommandHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus, ILogger<ConfirmOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _eventBus = eventBus; _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(ConfirmOrderCommand request, CancellationToken cancellationToken)
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

            // Confirm each leg
            foreach (var legRequest in request.Legs)
            {
                var leg = order.Legs.FirstOrDefault(l => l.Id == legRequest.TransactionId);
                if (leg == null)
                    return Result<OrderDto>.Failure($"Transaction leg {legRequest.TransactionId} not found on this order.");

                DealingPriceDetails? priceDetails = null;
                if (!string.IsNullOrWhiteSpace(legRequest.PriceType))
                    priceDetails = DealingPriceDetails.Create(legRequest.PriceType, legRequest.NAVPrice, leg.Currency);

                leg.Confirm(legRequest.NAVPrice, legRequest.Units, priceDetails, settlementDate: legRequest.SettlementDate);
                leg.UpdatedBy = _currentUser.UserId;
            }

            order.Confirm();
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            // Publish processed events for each confirmed leg (Holdings will update balances)
            foreach (var leg in order.Legs.Where(l => l.Units.HasValue))
            {
                await _eventBus.PublishAsync(new TransactionProcessedEvent(
                    leg.Id, leg.TenantId, leg.Type.ToString(),
                    leg.InvestmentAccountId, leg.ClassId, null,
                    leg.Units!.Value, leg.NAVPrice!.Value), cancellationToken);
            }

            await _eventBus.PublishAsync(
                new OrderConfirmedEvent(order.Id, order.TenantId, order.OrderType.ToString(), order.Legs[0].InvestmentAccountId),
                cancellationToken);

            _logger.LogInformation("Order confirmed: {OrderId}", order.Id);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (InvalidOperationException ex)
        {
            return Result<OrderDto>.Failure(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error confirming order {OrderId}", request.OrderId);
            return Result<OrderDto>.Failure("An error occurred while confirming the order.");
        }
    }
}
