using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfIndividualInvestorProfileRepository : IIndividualInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfIndividualInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<IndividualInvestorProfile?> GetByInvestorIdAsync(Guid investorId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.IndividualInvestorProfiles
            .FirstOrDefaultAsync(
                p => p.InvestorId == investorId &&
                     _context.Investors.Any(i => i.Id == p.InvestorId && i.TenantId == tenantId),
                ct);
    }

    public async Task AddAsync(IndividualInvestorProfile profile, CancellationToken ct = default)
    {
        await _context.IndividualInvestorProfiles.AddAsync(profile, ct);
    }

    public void Update(IndividualInvestorProfile profile)
    {
        _context.IndividualInvestorProfiles.Update(profile);
    }
}
