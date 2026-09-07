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
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.AcceptOrder;
public class AcceptOrderCommandHandler : IRequestHandler<AcceptOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<AcceptOrderCommandHandler> _logger;
    public AcceptOrderCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<AcceptOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(AcceptOrderCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");
            var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(request.OrderId, cancellationToken);
            if (order == null || order.TenantId != _currentUser.TenantId.Value)
                return Result<OrderDto>.Failure("Order not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("order", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            order.Accept(request.DealReference, request.ExpectedTradeDate, request.ExpectedSettlementDate);
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            _eventBuffer.Add(new OrderAcceptedEvent(order.Id, order.TenantId, order.DealReference!));
            _logger.LogInformation("Order accepted: {OrderId} DealRef={DealReference}", order.Id, order.DealReference);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException ex)
        {
            return Result<OrderDto>.Failure(ex.Message);
        }
    }
}
