using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IInvestmentAccountRepository
{
    Task<InvestmentAccount?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<InvestmentAccount>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task<bool> AccountNumberExistsAsync(string accountNumber, Guid tenantId, CancellationToken ct = default);
    Task<bool> AccountNumberExistsAsync(string accountNumber, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task AddAsync(InvestmentAccount account, CancellationToken ct = default);
    void Update(InvestmentAccount account);
}
