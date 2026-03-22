using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Repositories;

public class DepartmentRepository : IDepartmentRepository
{
    private readonly IfxDbContext _context;

    public DepartmentRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<Department?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Departments
            .Include(d => d.Tenant)
            .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);

    public async Task<List<Department>> GetAllAsync(CancellationToken cancellationToken = default)
        => await _context.Departments
            .Include(d => d.Tenant)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

    public async Task<List<Department>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default)
        => await _context.Departments
            .Include(d => d.Tenant)
            .AsNoTracking()
            .Where(d => d.TenantId == tenantId)
            .ToListAsync(cancellationToken);

    public async Task AddAsync(Department department, CancellationToken cancellationToken = default)
        => await _context.Departments.AddAsync(department, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default)
        => await _context.Departments.AnyAsync(d => d.Name == name && d.TenantId == tenantId, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default)
        => await _context.Departments.AnyAsync(d => d.Name == name && d.TenantId == tenantId && d.Id != excludeId, cancellationToken);

    public void Remove(Department department) => _context.Departments.Remove(department);
}
