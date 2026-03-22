namespace IFX.Modules.Auth.Domain.Authorization;

public interface IDepartmentRepository
{
    Task<Department?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<List<Department>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<List<Department>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Department department, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(Department department);
}
