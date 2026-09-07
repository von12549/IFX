using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.Registry.Abstractions.Interfaces;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Entities;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.CreateOrder;
public class CreateOrderCommandHandler : IRequestHandler<CreateOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICrmReader _crmReader;
    private readonly IRegistryReader _registryReader;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateOrderCommandHandler> _logger;
    public CreateOrderCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICrmReader crmReader, IRegistryReader registryReader, ICommittedEventBuffer eventBuffer, ILogger<CreateOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _crmReader = crmReader;
        _registryReader = registryReader;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(CreateOrderCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("order", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            if (!await _crmReader.IsInvestmentAccountKycApprovedAsync(request.InvestmentAccountId, tenantId, cancellationToken))
                return Result<OrderDto>.Failure("Investment account KYC is not approved.");
            Order order;
            var orderType = request.OrderType.ToUpperInvariant();
            if (orderType == "SUBSCRIPTIONORDER")
            {
                if (!await _registryReader.IsClassOpenForSubscriptionAsync(request.FromClassId, tenantId, cancellationToken))
                    return Result<OrderDto>.Failure("Fund class is not open for subscription.");
                order = Order.CreateSubscriptionOrder(tenantId, request.OrderReference, request.InvestmentAccountId, request.FromFundId, request.FromClassId, request.Amount, request.Currency, request.TradeDate);
            }
            else if (orderType == "REDEMPTIONORDER")
            {
                order = Order.CreateRedemptionOrder(tenantId, request.OrderReference, request.InvestmentAccountId, request.FromFundId, request.FromClassId, request.Amount, request.Currency, request.TradeDate);
            }
            else // SwitchOrder
            {
                if (request.ToFundId == null || request.ToClassId == null)
                    return Result<OrderDto>.Failure("ToFundId and ToClassId are required for SwitchOrder.");
                if (!await _registryReader.IsClassOpenForSubscriptionAsync(request.ToClassId.Value, tenantId, cancellationToken))
                    return Result<OrderDto>.Failure("Target fund class is not open for subscription.");
                order = Order.CreateSwitchOrder(tenantId, request.OrderReference, request.InvestmentAccountId, request.FromFundId, request.FromClassId, request.ToFundId.Value, request.ToClassId.Value, request.Amount, request.Currency, request.TradeDate);
            }

            order.CreatedBy = _currentUser.UserId;
            foreach (var leg in order.Legs)
                leg.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Orders.AddAsync(order, cancellationToken);
            _eventBuffer.Add(new OrderSubmittedEvent(order.Id, tenantId, order.OrderType.ToString(), order.OrderReference, order.Legs.Count));
            _logger.LogInformation("Order created: {OrderId} Type={OrderType} Legs={LegCount}", order.Id, order.OrderType, order.Legs.Count);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
    }
}
