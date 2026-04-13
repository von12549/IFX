using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfCorporateInvestorProfileRepository : ICorporateInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfCorporateInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<CorporateInvestorProfile?> GetByInvestorIdAsync(Guid investorId, CancellationToken ct = default)
    {
        return await _context.CorporateInvestorProfiles
            .FirstOrDefaultAsync(p => p.InvestorId == investorId, ct);
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
