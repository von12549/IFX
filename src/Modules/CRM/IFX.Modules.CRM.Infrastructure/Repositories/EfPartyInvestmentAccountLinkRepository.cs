using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfPartyInvestmentAccountLinkRepository : IPartyInvestmentAccountLinkRepository
{
    private readonly CrmDbContext _context;

    public EfPartyInvestmentAccountLinkRepository(CrmDbContext context) => _context = context;

    public async Task<IReadOnlyList<PartyInvestmentAccountLink>> GetLinksByAccountIdAsync(Guid accountId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyInvestmentAccountLinks
            .Where(l => l.InvestmentAccountId == accountId && l.TenantId == tenantId)
            .OrderBy(l => l.LinkOrder)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<PartyInvestmentAccountLink>> GetLinksByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyInvestmentAccountLinks
            .Where(l => l.PartyId == partyId && l.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<PartyInvestmentAccountLink?> GetAsync(Guid partyId, Guid accountId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyInvestmentAccountLinks
            .FirstOrDefaultAsync(l => l.PartyId == partyId && l.InvestmentAccountId == accountId && l.TenantId == tenantId, ct);
    }

    public async Task AddAsync(PartyInvestmentAccountLink link, CancellationToken ct = default)
    {
        await _context.PartyInvestmentAccountLinks.AddAsync(link, ct);
    }

    public void Remove(PartyInvestmentAccountLink link)
    {
        _context.PartyInvestmentAccountLinks.Remove(link);
    }
}
