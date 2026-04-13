using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Repositories;

public interface IPartyRoleAssignmentRepository
{
    Task<IReadOnlyList<PartyRoleAssignment>> GetRolesForPartyAsync(Guid partyId, Guid tenantId, CancellationToken ct = default);
    Task<bool> HasRoleAsync(Guid partyId, PartyFunctionalRole role, Guid tenantId, CancellationToken ct = default);
    Task<PartyRoleAssignment?> GetAsync(Guid partyId, PartyFunctionalRole role, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(PartyRoleAssignment assignment, CancellationToken ct = default);
    void Remove(PartyRoleAssignment assignment);
}
