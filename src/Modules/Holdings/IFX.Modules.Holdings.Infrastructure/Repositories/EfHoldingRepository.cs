using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Repositories;

public class EfHoldingRepository : IHoldingRepository
{
    private readonly HoldingsDbContext _context;

    public EfHoldingRepository(HoldingsDbContext context) => _context = context;

    public async Task<Holding?> GetByIdAsync(Guid tenantId, Guid holdingId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Holdings.FirstOrDefaultAsync(h => h.TenantId == tenantId && h.Id == holdingId, ct);
    }

    public async Task<Holding?> GetByAccountAndClassAsync(Guid tenantId, Guid investmentAccountId, Guid classId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Holdings.FirstOrDefaultAsync(h => h.TenantId == tenantId && h.InvestmentAccountId == investmentAccountId && h.ClassId == classId, ct);
    }

    public async Task<IReadOnlyList<Holding>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Holdings.Where(h => h.TenantId == tenantId).ToListAsync(ct);
    }

    public async Task<IReadOnlyList<Holding>> GetByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Holdings.Where(h => h.TenantId == tenantId && h.InvestmentAccountId == investmentAccountId).ToListAsync(ct);
    }

    public async Task<IReadOnlyList<Holding>> GetByClassAsync(Guid tenantId, Guid classId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Holdings.Where(h => h.TenantId == tenantId && h.ClassId == classId).ToListAsync(ct);
    }

    public async Task AddAsync(Holding holding, CancellationToken ct = default)
        => await _context.Holdings.AddAsync(holding, ct);

    public void Update(Holding holding)
        => _context.Holdings.Update(holding);
}
