using IFX.Modules.Transaction.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.ConfirmOrder;
public class ConfirmOrderCommandHandler : IRequestHandler<ConfirmOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<ConfirmOrderCommandHandler> _logger;
    public ConfirmOrderCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<ConfirmOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(ConfirmOrderCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");
            var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(_currentUser.TenantId.Value, request.OrderId, cancellationToken);
            if (order == null || order.TenantId != _currentUser.TenantId.Value)
                return Result<OrderDto>.Failure("Order not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("order", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            // Confirm each leg
            foreach (var legRequest in request.Legs)
            {
                var leg = order.Legs.FirstOrDefault(l => l.Id == legRequest.TransactionId);
                if (leg == null)
                    return Result<OrderDto>.Failure("A transaction leg was not found on this order.");
                DealingPriceDetails? priceDetails = null;
                if (!string.IsNullOrWhiteSpace(legRequest.PriceType))
                    priceDetails = DealingPriceDetails.Create(legRequest.PriceType, legRequest.NAVPrice, leg.Currency);
                leg.Confirm(legRequest.NAVPrice, legRequest.Units, priceDetails, settlementDate: legRequest.SettlementDate);
                leg.UpdatedBy = _currentUser.UserId;
            }

            order.Confirm();
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            // Publish processed events for each confirmed leg (Holdings will update balances)
            foreach (var leg in order.Legs.Where(l => l.Units.HasValue))
            {
                _eventBuffer.Add(new TransactionProcessed(leg.Id, leg.Type.ToString(), leg.InvestmentAccountId, leg.ClassId, null, leg.Units!.Value, leg.NAVPrice!.Value));
            }

            _logger.LogInformation("Order confirmed: {OrderId}", order.Id);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException)
        {
            return Result<OrderDto>.Failure("The requested state transition is not allowed.");
        }
    }
}
