using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface ICorporateInvestorProfileRepository
{
    Task<CorporateInvestorProfile?> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(CorporateInvestorProfile profile, CancellationToken ct = default);
    void Update(CorporateInvestorProfile profile);
}
