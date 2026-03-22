namespace IFX.Modules.Auth.Domain.Authorization;

public interface IRoleGroupRepository
{
    Task<RoleGroup?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<RoleGroup?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task<RoleGroup?> GetByIdWithRolesAsync(Guid id, CancellationToken cancellationToken = default);
    Task<List<RoleGroup>> GetAllAsync(CancellationToken cancellationToken = default);
    Task AddAsync(RoleGroup group, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(RoleGroup group);
}
