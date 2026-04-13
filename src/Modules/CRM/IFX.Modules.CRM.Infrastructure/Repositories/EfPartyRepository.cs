using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfPartyRepository : IPartyRepository
{
    private readonly CrmDbContext _context;

    public EfPartyRepository(CrmDbContext context)
    {
        _context = context;
    }

    public async Task<Party?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Parties
            .Include(p => p.RoleAssignments)
            .FirstOrDefaultAsync(p => p.Id == id && p.TenantId == tenantId, ct);
    }

    public async Task<List<Party>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Parties
            .Include(p => p.RoleAssignments)
            .Where(p => p.TenantId == tenantId)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);
    }

    public async Task<bool> CodeExistsAsync(string partyCode, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.Parties
            .AnyAsync(p => p.PartyCode == partyCode && p.TenantId == tenantId, ct);
    }

    public async Task<bool> CodeExistsAsync(string partyCode, Guid tenantId, Guid excludeId, CancellationToken ct = default)
    {
        return await _context.Parties
            .AnyAsync(p => p.PartyCode == partyCode && p.TenantId == tenantId && p.Id != excludeId, ct);
    }

    public async Task<IReadOnlyList<Party>> GetByLegalStructureAsync(Guid tenantId, PartyLegalStructure legalStructure, CancellationToken ct = default)
    {
        return await _context.Parties
            .Include(p => p.RoleAssignments)
            .Where(p => p.TenantId == tenantId && p.LegalStructure == legalStructure)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);
    }

    public async Task AddAsync(Party party, CancellationToken ct = default)
    {
        await _context.Parties.AddAsync(party, ct);
    }

    public void Remove(Party party)
    {
        _context.Parties.Remove(party);
    }
}
