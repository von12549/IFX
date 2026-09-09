using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface ITrustInvestorProfileRepository
{
    Task<TrustInvestorProfile?> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(TrustInvestorProfile profile, CancellationToken ct = default);
    void Update(TrustInvestorProfile profile);
}
