using IFX.Modules.Holdings.Domain.Entities;

namespace IFX.Modules.Holdings.Domain.Repositories;

public interface IHoldingRepository
{
    Task<Holding?> GetByIdAsync(Guid holdingId, CancellationToken ct = default);
    Task<Holding?> GetByAccountAndClassAsync(Guid tenantId, Guid investmentAccountId, Guid classId, CancellationToken ct = default);
    Task<IReadOnlyList<Holding>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<Holding>> GetByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default);
    Task<IReadOnlyList<Holding>> GetByClassAsync(Guid tenantId, Guid classId, CancellationToken ct = default);
    Task AddAsync(Holding holding, CancellationToken ct = default);
    void Update(Holding holding);
}
