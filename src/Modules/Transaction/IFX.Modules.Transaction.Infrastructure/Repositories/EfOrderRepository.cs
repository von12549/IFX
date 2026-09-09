using IFX.Modules.Transaction.Domain.Entities;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Transaction.Infrastructure.Repositories;

public class EfOrderRepository : IOrderRepository
{
    private readonly TransactionDbContext _context;

    public EfOrderRepository(TransactionDbContext context) => _context = context;

    public async Task<Order?> GetByIdAsync(Guid tenantId, Guid orderId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Orders.FirstOrDefaultAsync(o => o.TenantId == tenantId && o.Id == orderId, ct);
    }

    public async Task<Order?> GetByIdWithLegsAsync(Guid tenantId, Guid orderId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Orders
            .Include(o => o.Legs)
            .FirstOrDefaultAsync(o => o.TenantId == tenantId && o.Id == orderId, ct);
    }

    public async Task<IReadOnlyList<Order>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Orders
            .Where(o => o.TenantId == tenantId)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<Order>> GetByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Orders
            .Include(o => o.Legs)
            .Where(o => o.TenantId == tenantId && o.Legs.Any(l => l.InvestmentAccountId == investmentAccountId))
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct);
    }

    public async Task AddAsync(Order order, CancellationToken ct = default)
        => await _context.Orders.AddAsync(order, ct);

    public void Update(Order order)
        => _context.Orders.Update(order);
}
