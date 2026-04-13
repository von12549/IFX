using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IPartyRelationshipRepository
{
    Task<PartyRelationship?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<PartyRelationship>> GetByPartyIdAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<PartyRelationship>> GetByFromPartyAsync(Guid fromPartyId, Guid tenantId, CancellationToken ct = default);
    Task<PartyRelationship?> GetAsync(Guid fromPartyId, Guid toPartyId, PartyRelationshipType type, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(PartyRelationship relationship, CancellationToken ct = default);
    void Update(PartyRelationship relationship);
}
