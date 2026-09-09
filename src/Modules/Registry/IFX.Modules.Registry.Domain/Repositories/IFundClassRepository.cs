using IFX.Modules.Registry.Domain.Entities;

namespace IFX.Modules.Registry.Domain.Repositories;

public interface IFundClassRepository
{
    Task<FundClass?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<List<FundClass>> GetByFundIdAsync(Guid fundId, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string classCode, Guid fundId, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string classCode, Guid fundId, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task AddAsync(FundClass fundClass, CancellationToken ct = default);
    void Remove(FundClass fundClass);
}
