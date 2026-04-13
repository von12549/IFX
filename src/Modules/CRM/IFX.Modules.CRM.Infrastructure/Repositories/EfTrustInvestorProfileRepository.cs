using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfTrustInvestorProfileRepository : ITrustInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfTrustInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<TrustInvestorProfile?> GetByInvestorIdAsync(Guid investorId, CancellationToken ct = default)
    {
        return await _context.TrustInvestorProfiles
            .FirstOrDefaultAsync(p => p.InvestorId == investorId, ct);
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
