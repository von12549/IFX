using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfInvestorRepository : IInvestorRepository
{
    private readonly CrmDbContext _context;

    public EfInvestorRepository(CrmDbContext context)
    {
        _context = context;
    }

    public async Task<Investor?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Investors
            .Include(i => i.IndividualProfile)
            .Include(i => i.CorporateProfile)
            .Include(i => i.TrustProfile)
            .FirstOrDefaultAsync(i => i.Id == id && i.TenantId == tenantId, ct);
    }

    public async Task<List<Investor>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Investors
            .Where(i => i.TenantId == tenantId)
            .OrderBy(i => i.Name)
            .ToListAsync(ct);
    }

    public async Task<List<Investor>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Investors
            .Where(i => i.PartyId == partyId && i.TenantId == tenantId)
            .OrderBy(i => i.Name)
            .ToListAsync(ct);
    }

    public async Task<bool> CodeExistsAsync(string investorCode, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Investors
            .AnyAsync(i => i.InvestorCode == investorCode && i.TenantId == tenantId, ct);
    }

    public async Task<bool> CodeExistsAsync(string investorCode, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        return await _context.Investors
            .AnyAsync(i => i.InvestorCode == investorCode && i.TenantId == tenantId && i.Id != excludeId, ct);
    }

    public async Task AddAsync(Investor investor, CancellationToken ct = default)
    {
        await _context.Investors.AddAsync(investor, ct);
    }

    public void Remove(Investor investor)
    {
        _context.Investors.Remove(investor);
    }
}
