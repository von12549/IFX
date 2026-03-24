namespace IFX.Modules.Auth.Domain.Authorization;

public interface IPolicyDefinitionRepository
{
    Task<PolicyDefinition?> GetAsync(Guid tenantId, string resourceType, string action, CancellationToken ct = default);
    Task<List<PolicyDefinition>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task AddAsync(PolicyDefinition policy, CancellationToken ct = default);
    void Remove(PolicyDefinition policy);
    Task<bool> ExistsAsync(Guid tenantId, string resourceType, string action, CancellationToken ct = default);
    Task<PolicyDefinition?> GetByIdAsync(Guid id, CancellationToken ct = default);
}
