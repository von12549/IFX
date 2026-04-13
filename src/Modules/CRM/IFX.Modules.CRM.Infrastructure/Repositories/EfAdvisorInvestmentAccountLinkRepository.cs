using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfAdvisorInvestmentAccountLinkRepository : IAdvisorInvestmentAccountLinkRepository
{
    private readonly CrmDbContext _context;

    public EfAdvisorInvestmentAccountLinkRepository(CrmDbContext context) => _context = context;

    public async Task<IReadOnlyList<AdvisorInvestmentAccountLink>> GetByAccountIdAsync(Guid accountId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.AdvisorInvestmentAccountLinks
            .Where(l => l.InvestmentAccountId == accountId && l.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<AdvisorInvestmentAccountLink?> GetAsync(Guid advisorPartyId, Guid accountId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.AdvisorInvestmentAccountLinks
            .FirstOrDefaultAsync(l => l.AdvisorPartyId == advisorPartyId && l.InvestmentAccountId == accountId && l.TenantId == tenantId, ct);
    }

    public async Task AddAsync(AdvisorInvestmentAccountLink link, CancellationToken ct = default)
    {
        await _context.AdvisorInvestmentAccountLinks.AddAsync(link, ct);
    }

    public void Update(AdvisorInvestmentAccountLink link)
    {
        _context.AdvisorInvestmentAccountLinks.Update(link);
    }

    public void Remove(AdvisorInvestmentAccountLink link)
    {
        _context.AdvisorInvestmentAccountLinks.Remove(link);
    }
}
