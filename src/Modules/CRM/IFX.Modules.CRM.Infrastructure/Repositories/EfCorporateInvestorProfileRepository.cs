using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfCorporateInvestorProfileRepository : ICorporateInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfCorporateInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<CorporateInvestorProfile?> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.CorporateInvestorProfiles
            .FirstOrDefaultAsync(
                p => p.InvestorId == investorId &&
                     _context.Investors.Any(i => i.Id == p.InvestorId && i.TenantId == tenantId),
                ct);
    }

    public async Task AddAsync(CorporateInvestorProfile profile, CancellationToken ct = default)
    {
        await _context.CorporateInvestorProfiles.AddAsync(profile, ct);
    }

    public void Update(CorporateInvestorProfile profile)
    {
        _context.CorporateInvestorProfiles.Update(profile);
    }
}
