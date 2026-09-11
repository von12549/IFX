using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.RejectOrder;
public class RejectOrderCommandHandler : IRequestHandler<RejectOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<RejectOrderCommandHandler> _logger;
    public RejectOrderCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<RejectOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(RejectOrderCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");
            var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(_currentUser.TenantId.Value, request.OrderId, cancellationToken);
            if (order == null || order.TenantId != _currentUser.TenantId.Value)
                return Result<OrderDto>.Failure("Order not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("order", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            order.Reject(request.Reason);
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            _logger.LogInformation("Order rejected: {OrderId} Reason={Reason}", order.Id, request.Reason);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException)
        {
            return Result<OrderDto>.Failure("The requested state transition is not allowed.");
        }
    }
}
