namespace IFX.Modules.IAM.Domain.Access;

public interface IRoleRepository
{
    Task<Role?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default);
    Task<Role?> GetByNameAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<Role?> GetByIdWithPermissionsAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default);
    Task<List<Role>> GetAcrossTenantsAsync(int maxRows, CancellationToken cancellationToken = default);
    Task<List<Role>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Role role, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(Role role);
}
