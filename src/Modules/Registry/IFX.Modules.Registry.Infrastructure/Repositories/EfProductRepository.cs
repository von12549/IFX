using IFX.Modules.Registry.Domain.Entities;
using IFX.Modules.Registry.Domain.Repositories;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Repositories;

public class EfProductRepository : IProductRepository
{
    private readonly RegistryDbContext _context;

    public EfProductRepository(RegistryDbContext context)
    {
        _context = context;
    }

    public async Task<Product?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.TenantId == tenantId, ct);
    }

    public async Task<List<Product>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Products
            .Where(p => p.TenantId == tenantId)
            .OrderBy(p => p.ProductCode)
            .ToListAsync(ct);
    }

    public async Task<List<Fund>> GetFundsByProductIdAsync(Guid productId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Funds
            .Where(f => f.ProductId == productId && f.TenantId == tenantId)
            .OrderBy(f => f.FundCode)
            .ToListAsync(ct);
    }

    public async Task<bool> CodeExistsAsync(string productCode, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Products
            .AnyAsync(p => p.ProductCode == productCode.ToUpperInvariant() && p.TenantId == tenantId, ct);
    }

    public async Task<bool> CodeExistsAsync(string productCode, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Products
            .AnyAsync(p => p.ProductCode == productCode.ToUpperInvariant() && p.TenantId == tenantId && p.Id != excludeId, ct);
    }

    public async Task AddAsync(Product product, CancellationToken ct = default)
    {
        await _context.Products.AddAsync(product, ct);
    }

    public void Remove(Product product)
    {
        _context.Products.Remove(product);
    }
}
