using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;

namespace IFX.Modules.Transaction.Application.Queries.GetOrderById;

public class GetOrderByIdQueryHandler : IRequestHandler<GetOrderByIdQuery, Result<OrderDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;

    public GetOrderByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
    }

    public async Task<Result<OrderDto>> Handle(GetOrderByIdQuery request, CancellationToken cancellationToken)
    {
        if (_currentUser.TenantId == null)
            return Result<OrderDto>.Failure("Tenant context required.");

        var order = await _unitOfWork.Orders.GetByIdWithLegsAsync(_currentUser.TenantId.Value, request.OrderId, cancellationToken);
        if (order == null || order.TenantId != _currentUser.TenantId.Value)
            return Result<OrderDto>.Failure("Order not found.");

        return Result<OrderDto>.Success(_mapper.Map<OrderDto>(order));
    }
}
