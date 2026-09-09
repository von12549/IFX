using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfTrustInvestorProfileRepository : ITrustInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfTrustInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<TrustInvestorProfile?> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.TrustInvestorProfiles
            .FirstOrDefaultAsync(
                p => p.InvestorId == investorId &&
                     _context.Investors.Any(i => i.Id == p.InvestorId && i.TenantId == tenantId),
                ct);
    }

    public async Task AddAsync(TrustInvestorProfile profile, CancellationToken ct = default)
    {
        await _context.TrustInvestorProfiles.AddAsync(profile, ct);
    }

    public void Update(TrustInvestorProfile profile)
    {
        _context.TrustInvestorProfiles.Update(profile);
    }
}
