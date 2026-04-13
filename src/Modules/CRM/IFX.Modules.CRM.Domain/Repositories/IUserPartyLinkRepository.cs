using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IUserPartyLinkRepository
{
    Task<UserPartyLink?> GetByUserIdAsync(Guid userId, Guid tenantId, CancellationToken ct = default);
    Task<UserPartyLink?> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<UserPartyLink>> GetAllByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(UserPartyLink link, CancellationToken ct = default);
    void Remove(UserPartyLink link);
}
