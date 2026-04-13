using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfIndividualInvestorProfileRepository : IIndividualInvestorProfileRepository
{
    private readonly CrmDbContext _context;

    public EfIndividualInvestorProfileRepository(CrmDbContext context) => _context = context;

    public async Task<IndividualInvestorProfile?> GetByInvestorIdAsync(Guid investorId, CancellationToken ct = default)
    {
        return await _context.IndividualInvestorProfiles
            .FirstOrDefaultAsync(p => p.InvestorId == investorId, ct);
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
