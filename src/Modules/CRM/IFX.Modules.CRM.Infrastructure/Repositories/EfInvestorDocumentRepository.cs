using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfInvestorDocumentRepository : IInvestorDocumentRepository
{
    private readonly CrmDbContext _context;

    public EfInvestorDocumentRepository(CrmDbContext context) => _context = context;

    public async Task<IReadOnlyList<InvestorDocument>> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.InvestorDocuments
            .Where(d => d.InvestorId == investorId && d.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<InvestorDocument?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.InvestorDocuments
            .FirstOrDefaultAsync(d => d.Id == id && d.TenantId == tenantId, ct);
    }

    public async Task AddAsync(InvestorDocument document, CancellationToken ct = default)
    {
        await _context.InvestorDocuments.AddAsync(document, ct);
    }

    public void Remove(InvestorDocument document)
    {
        _context.InvestorDocuments.Remove(document);
    }
}
