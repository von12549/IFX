using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfPartyRelationshipRepository : IPartyRelationshipRepository
{
    private readonly CrmDbContext _context;

    public EfPartyRelationshipRepository(CrmDbContext context) => _context = context;

    public async Task<PartyRelationship?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PartyRelationships
            .FirstOrDefaultAsync(r => r.Id == id && r.TenantId == tenantId, ct);
    }

    public async Task<IReadOnlyList<PartyRelationship>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PartyRelationships
            .Where(r => (r.FromPartyId == partyId || r.ToPartyId == partyId) && r.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<PartyRelationship>> GetByFromPartyAsync(Guid fromPartyId, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PartyRelationships
            .Where(r => r.FromPartyId == fromPartyId && r.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<PartyRelationship?> GetAsync(Guid fromPartyId, Guid toPartyId, PartyRelationshipType type, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PartyRelationships
            .FirstOrDefaultAsync(r => r.FromPartyId == fromPartyId && r.ToPartyId == toPartyId && r.RelationshipType == type && r.TenantId == tenantId, ct);
    }

    public async Task AddAsync(PartyRelationship relationship, CancellationToken ct = default)
    {
        await _context.PartyRelationships.AddAsync(relationship, ct);
    }

    public void Update(PartyRelationship relationship)
    {
        _context.PartyRelationships.Update(relationship);
    }
}
