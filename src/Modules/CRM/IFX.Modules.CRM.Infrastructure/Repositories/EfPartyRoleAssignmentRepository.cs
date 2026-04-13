using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfPartyRoleAssignmentRepository : IPartyRoleAssignmentRepository
{
    private readonly CrmDbContext _context;

    public EfPartyRoleAssignmentRepository(CrmDbContext context) => _context = context;

    public async Task<IReadOnlyList<PartyRoleAssignment>> GetRolesForPartyAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyRoleAssignments
            .Where(r => r.PartyId == partyId && r.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<bool> HasRoleAsync(Guid partyId, PartyFunctionalRole role, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyRoleAssignments
            .AnyAsync(r => r.PartyId == partyId && r.Role == role && r.TenantId == tenantId, ct);
    }

    public async Task<PartyRoleAssignment?> GetAsync(Guid partyId, PartyFunctionalRole role, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyRoleAssignments
            .FirstOrDefaultAsync(r => r.PartyId == partyId && r.Role == role && r.TenantId == tenantId, ct);
    }

    public async Task AddAsync(PartyRoleAssignment assignment, CancellationToken ct = default)
    {
        await _context.PartyRoleAssignments.AddAsync(assignment, ct);
    }

    public void Remove(PartyRoleAssignment assignment)
    {
        _context.PartyRoleAssignments.Remove(assignment);
    }
}
