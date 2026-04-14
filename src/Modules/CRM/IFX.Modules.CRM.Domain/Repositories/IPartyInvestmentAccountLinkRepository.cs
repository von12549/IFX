using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IPartyInvestmentAccountLinkRepository
{
    Task<IReadOnlyList<PartyInvestmentAccountLink>> GetLinksByAccountIdAsync(Guid accountId, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<PartyInvestmentAccountLink>> GetLinksByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<PartyInvestmentAccountLink?> GetAsync(Guid partyId, Guid accountId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(PartyInvestmentAccountLink link, CancellationToken ct = default);
    void Remove(PartyInvestmentAccountLink link);
}
