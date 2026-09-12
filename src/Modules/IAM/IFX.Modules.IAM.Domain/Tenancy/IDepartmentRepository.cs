namespace IFX.Modules.IAM.Domain.Tenancy;

public interface IDepartmentRepository
{
    Task<Department?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default);
    Task<List<Department>> GetAcrossTenantsAsync(int maxRows, CancellationToken cancellationToken = default);
    Task<List<Department>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default);
    Task AddAsync(Department department, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default);
    Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default);
    void Remove(Department department);
}
