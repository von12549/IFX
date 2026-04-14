using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Repositories;
using IFX.Modules.Registry.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Repositories;

public class EfFundRepository : IFundRepository
{
    private readonly RegistryDbContext _context;

    public EfFundRepository(RegistryDbContext context)
    {
        _context = context;
    }

    public async Task<Fund?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Funds
            .FirstOrDefaultAsync(f => f.Id == id && f.TenantId == tenantId, ct);
    }

    public async Task<List<Fund>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Funds
            .Where(f => f.TenantId == tenantId)
            .OrderBy(f => f.FundCode)
            .ToListAsync(ct);
    }

    public async Task<bool> CodeExistsAsync(string fundCode, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Funds
            .AnyAsync(f => f.FundCode == fundCode.ToUpperInvariant() && f.TenantId == tenantId, ct);
    }

    public async Task<bool> CodeExistsAsync(string fundCode, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        return await _context.Funds
            .AnyAsync(f => f.FundCode == fundCode.ToUpperInvariant() && f.TenantId == tenantId && f.Id != excludeId, ct);
    }

    public async Task AddAsync(Fund fund, CancellationToken ct = default)
    {
        await _context.Funds.AddAsync(fund, ct);
    }

    public void Remove(Fund fund)
    {
        _context.Funds.Remove(fund);
    }
}
