using IFX.Modules.Transaction.Domain.Entities;

namespace IFX.Modules.Transaction.Domain.Repositories;

public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(Guid orderId, CancellationToken ct = default);
    Task<Order?> GetByIdWithLegsAsync(Guid orderId, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    void Update(Order order);
}
