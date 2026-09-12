namespace IFX.Modules.IAM.Domain.Access;

public interface IPolicyDefinitionRepository
{
    Task<PolicyDefinition?> GetAsync(Guid tenantId, string resourceType, string action, CancellationToken ct = default);
    Task<List<PolicyDefinition>> GetByTenantIdAsync(Guid tenantId, CancellationToken ct = default);
    Task AddAsync(PolicyDefinition policy, CancellationToken ct = default);
    void Remove(PolicyDefinition policy);
    Task<bool> ExistsAsync(Guid tenantId, string resourceType, string action, CancellationToken ct = default);
    Task<PolicyDefinition?> GetTenantByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default);
    Task<PolicyDefinition?> GetPlatformByIdAsync(Guid id, CancellationToken ct = default);
    Task<PolicyDefinition?> GetPlatformAsync(string resourceType, string action, CancellationToken ct = default);
    Task<PolicyDefinition?> GetPlatformByGlobalRoleAsync(string resourceType, string action, string globalRole, CancellationToken ct = default);
    Task<List<PolicyDefinition>> GetPlatformPoliciesAsync(CancellationToken ct = default);
    Task<bool> ExistsPlatformAsync(string resourceType, string action, CancellationToken ct = default);
}
