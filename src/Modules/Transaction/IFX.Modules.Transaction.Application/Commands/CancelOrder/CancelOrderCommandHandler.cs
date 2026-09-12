using IFX.Modules.Transaction.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Commands.CancelOrder;
public class CancelOrderCommandHandler : IRequestHandler<CancelOrderCommand, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CancelOrderCommandHandler> _logger;
    public CancelOrderCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<CancelOrderCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<OrderDto>> Handle(CancelOrderCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<OrderDto>.Failure("Tenant context required.");
            var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(_currentUser.TenantId.Value, request.OrderId, cancellationToken);
            if (order == null || order.TenantId != _currentUser.TenantId.Value)
                return Result<OrderDto>.Failure("Order not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("order", "delete", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            order.Cancel(request.Reason);
            foreach (var leg in order.Legs)
                leg.Cancel(request.Reason);
            order.UpdatedBy = _currentUser.UserId;
            _unitOfWork.Orders.Update(order);
            _logger.LogInformation("Order cancelled: {OrderId}", order.Id);
            return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException)
        {
            return Result<OrderDto>.Failure("The requested state transition is not allowed.");
        }
    }
}
