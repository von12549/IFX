using IFX.Modules.Registry.Domain.Entities;

namespace IFX.Modules.Registry.Domain.Repositories;

public interface IProductRepository
{
    Task<Product?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<List<Product>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task<List<Fund>> GetFundsByProductIdAsync(Guid productId, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string productCode, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string productCode, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task AddAsync(Product product, CancellationToken ct = default);
    void Remove(Product product);
}
