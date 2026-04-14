using IFX.Modules.CRM.Domain.Entities;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IInvestorDocumentRepository
{
    Task<IReadOnlyList<InvestorDocument>> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default);
    Task<InvestorDocument?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(InvestorDocument document, CancellationToken ct = default);
    void Remove(InvestorDocument document);
}
