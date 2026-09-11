using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;

namespace IFX.Modules.Transaction.Application.Queries.GetOrders;

public class GetOrdersQueryHandler : IRequestHandler<GetOrdersQuery, Result<IReadOnlyList<OrderSummaryDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;

    public GetOrdersQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
    }

    public async Task<Result<IReadOnlyList<OrderSummaryDto>>> Handle(GetOrdersQuery request, CancellationToken cancellationToken)
    {
        if (_currentUser.TenantId == null)
            return Result<IReadOnlyList<OrderSummaryDto>>.Success(Array.Empty<OrderSummaryDto>());

        var orders = await _unitOfWork.Orders.GetByTenantAsync(_currentUser.TenantId.Value, cancellationToken);
        var dtos = orders.Select(o => _mapper.Map<OrderSummaryDto>(o)).ToList();
        return Result<IReadOnlyList<OrderSummaryDto>>.Success(dtos);
    }
}
