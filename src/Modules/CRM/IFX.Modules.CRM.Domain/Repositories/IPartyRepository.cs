using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IPartyRepository
{
    Task<Party?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<List<Party>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string partyCode, Guid tenantId, CancellationToken ct = default);
    Task<bool> CodeExistsAsync(string partyCode, Guid tenantId, Guid excludeId, CancellationToken ct = default);
    Task<IReadOnlyList<Party>> GetByLegalStructureAsync(Guid tenantId, PartyLegalStructure legalStructure, CancellationToken ct = default);
    Task AddAsync(Party party, CancellationToken ct = default);
    void Remove(Party party);
}
