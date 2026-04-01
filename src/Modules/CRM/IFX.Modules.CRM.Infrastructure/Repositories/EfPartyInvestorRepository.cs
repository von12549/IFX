using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.CRM.Infrastructure.Repositories;

public class EfPartyInvestorRepository : IPartyInvestorRepository
{
    private readonly CrmDbContext _context;

    public EfPartyInvestorRepository(CrmDbContext context)
    {
        _context = context;
    }

    public async Task<List<PartyInvestorRelationship>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default)
    {
        return await _context.PartyInvestorRelationships
            .Where(r => r.PartyId == partyId && r.TenantId == tenantId)
            .ToListAsync(ct);
    }

    public async Task<PartyInvestorRelationship?> GetAsync(Guid partyId, Guid investorId, RelationshipType type, CancellationToken ct = default)
    {
        return await _context.PartyInvestorRelationships
            .FirstOrDefaultAsync(r => r.PartyId == partyId && r.InvestorId == investorId && r.RelationshipType == type, ct);
    }

    public async Task<bool> ExistsAsync(Guid partyId, Guid investorId, RelationshipType type, CancellationToken ct = default)
    {
        return await _context.PartyInvestorRelationships
            .AnyAsync(r => r.PartyId == partyId && r.InvestorId == investorId && r.RelationshipType == type, ct);
    }

    public async Task AddAsync(PartyInvestorRelationship relationship, CancellationToken ct = default)
    {
        await _context.PartyInvestorRelationships.AddAsync(relationship, ct);
    }

    public void Remove(PartyInvestorRelationship relationship)
    {
        _context.PartyInvestorRelationships.Remove(relationship);
    }
}
