namespace IFX.Modules.Auth.Domain.Authorization;

public interface IRoleRepository
{
    Task<Role?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Role?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task<Role?> GetByIdWithPermissionsAsync(Guid id, CancellationToken cancellationToken = default);
    Task<List<Role>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<List<Role>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Role role, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(Role role);
}
