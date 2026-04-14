using IFX.Modules.Registry.Domain.Entities;

namespace IFX.Modules.Registry.Domain.Repositories;

public interface IFundRepository
{
    Task<Fund?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<List<Fund>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string fundCode, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string fundCode, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task AddAsync(Fund fund, CancellationToken ct = default);
    void Remove(Fund fund);
}
