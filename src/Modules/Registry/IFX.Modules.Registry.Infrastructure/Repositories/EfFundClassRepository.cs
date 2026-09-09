using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Repositories;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Repositories;

public class EfFundClassRepository : IFundClassRepository
{
    private readonly RegistryDbContext _context;

    public EfFundClassRepository(RegistryDbContext context)
    {
        _context = context;
    }

    public async Task<FundClass?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.FundClasses
            .FirstOrDefaultAsync(fc => fc.Id == id && fc.TenantId == tenantId, ct);
    }

    public async Task<List<FundClass>> GetByFundIdAsync(Guid fundId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.FundClasses
            .Where(fc => fc.FundId == fundId && fc.TenantId == tenantId)
            .OrderBy(fc => fc.ClassCode)
            .ToListAsync(ct);
    }

    public async Task<bool> CodeExistsAsync(string classCode, Guid fundId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.FundClasses
            .AnyAsync(fc => fc.ClassCode == classCode.ToUpperInvariant() && fc.FundId == fundId && fc.TenantId == tenantId, ct);
    }

    public async Task<bool> CodeExistsAsync(string classCode, Guid fundId, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.FundClasses
            .AnyAsync(fc => fc.ClassCode == classCode.ToUpperInvariant() && fc.FundId == fundId && fc.TenantId == tenantId && fc.Id != excludeId, ct);
    }

    public async Task AddAsync(FundClass fundClass, CancellationToken ct = default)
    {
        await _context.FundClasses.AddAsync(fundClass, ct);
    }

    public void Remove(FundClass fundClass)
    {
        _context.FundClasses.Remove(fundClass);
    }
}
