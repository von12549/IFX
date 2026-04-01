using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IPartyInvestorRepository
{
    Task<List<PartyInvestorRelationship>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<PartyInvestorRelationship?> GetAsync(Guid partyId, Guid investorId, RelationshipType type, CancellationToken ct = default);
    Task<bool> ExistsAsync(Guid partyId, Guid investorId, RelationshipType type, CancellationToken ct = default);
    Task AddAsync(PartyInvestorRelationship relationship, CancellationToken ct = default);
    void Remove(PartyInvestorRelationship relationship);
}
