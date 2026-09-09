using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Repositories;

public class RoleRepository : IRoleRepository
{
    private readonly IfxDbContext _context;

    public RoleRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<Role?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles.FirstOrDefaultAsync(r => r.Id == id && r.TenantId == tenantId, cancellationToken);
    }

    public async Task<Role?> GetByNameAsync(string name, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles.FirstOrDefaultAsync(r => r.Name == name && r.TenantId == tenantId, cancellationToken);
    }

    public async Task<Role?> GetByIdWithPermissionsAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles
            .Include(r => r.Tenant)
            .Include(r => r.Permissions)
            .FirstOrDefaultAsync(r => r.Id == id && r.TenantId == tenantId, cancellationToken);
    }

    public async Task<List<Role>> GetAcrossTenantsAsync(int maxRows, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.RequireBoundedLimit(maxRows);
        return await _context.Roles.Include(r => r.Tenant).AsNoTracking().OrderBy(r => r.Id).Take(maxRows).ToListAsync(cancellationToken);
    }

    public async Task<List<Role>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles.Include(r => r.Tenant).Where(r => r.TenantId == tenantId).AsNoTracking().ToListAsync(cancellationToken);
    }

    public async Task AddAsync(Role role, CancellationToken cancellationToken = default)
        => await _context.Roles.AddAsync(role, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles.AnyAsync(r => r.Name == name && r.TenantId == tenantId, cancellationToken);
    }

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.Roles.AnyAsync(r => r.Name == name && r.TenantId == tenantId && r.Id != excludeId, cancellationToken);
    }

    public void Remove(Role role) => _context.Roles.Remove(role);
}
