namespace IFX.Modules.Auth.Domain.Authorization;

public interface IPermissionRepository
{
    Task<Permission?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Permission?> GetByNameAsync(string name, CancellationToken cancellationToken = default);
    Task<List<Permission>> GetAllAsync(CancellationToken cancellationToken = default);
    Task AddAsync(Permission permission, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(Permission permission);
}
