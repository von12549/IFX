using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IAdvisorInvestmentAccountLinkRepository
{
    Task<IReadOnlyList<AdvisorInvestmentAccountLink>> GetByAccountIdAsync(Guid accountId, Guid tenantId, CancellationToken ct = default);
    Task<AdvisorInvestmentAccountLink?> GetAsync(Guid advisorPartyId, Guid accountId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(AdvisorInvestmentAccountLink link, CancellationToken ct = default);
    void Update(AdvisorInvestmentAccountLink link);
    void Remove(AdvisorInvestmentAccountLink link);
}
