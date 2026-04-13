using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IIndividualInvestorProfileRepository
{
    Task<IndividualInvestorProfile?> GetByInvestorIdAsync(Guid investorId, CancellationToken ct = default);
    Task AddAsync(IndividualInvestorProfile profile, CancellationToken ct = default);
    void Update(IndividualInvestorProfile profile);
}
