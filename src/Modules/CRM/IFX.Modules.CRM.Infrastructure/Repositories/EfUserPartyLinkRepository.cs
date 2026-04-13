using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfUserPartyLinkRepository : IUserPartyLinkRepository
{
    private readonly CrmDbContext _context;

    public EfUserPartyLinkRepository(CrmDbContext context) => _context = context;

    public async Task<UserPartyLink?> GetByUserIdAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.UserPartyLinks
            .FirstOrDefaultAsync(l => l.UserId == userId && l.TenantId == tenantId, ct);
    }

    public async Task<UserPartyLink?> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.UserPartyLinks
            .FirstOrDefaultAsync(l => l.PartyId == partyId && l.TenantId == tenantId, ct);
    }

    public async Task<IReadOnlyList<UserPartyLink>> GetAllByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.UserPartyLinks
            .Where(l => l.PartyId == partyId && l.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task AddAsync(UserPartyLink link, CancellationToken ct = default)
    {
        await _context.UserPartyLinks.AddAsync(link, ct);
    }

    public void Remove(UserPartyLink link)
    {
        _context.UserPartyLinks.Remove(link);
    }
}
