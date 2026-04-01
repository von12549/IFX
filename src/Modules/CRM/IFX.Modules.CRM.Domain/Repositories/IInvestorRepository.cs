using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IInvestorRepository
{
    Task<Investor?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<List<Investor>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task<List<Investor>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string investorCode, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string investorCode, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task AddAsync(Investor investor, CancellationToken ct = default);
    void Remove(Investor investor);
}
