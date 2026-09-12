using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Access.Repositories;

public class RoleGroupRepository : IRoleGroupRepository
{
    private readonly IfxDbContext _context;

    public RoleGroupRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<RoleGroup?> GetByIdAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups.FirstOrDefaultAsync(g => g.Id == id && g.TenantId == tenantId, cancellationToken);
    }

    public async Task<RoleGroup?> GetByNameAsync(string name, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups.FirstOrDefaultAsync(g => g.Name == name && g.TenantId == tenantId, cancellationToken);
    }

    public async Task<RoleGroup?> GetByIdWithRolesAsync(Guid id, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups
            .Include(g => g.Roles)
            .FirstOrDefaultAsync(g => g.Id == id && g.TenantId == tenantId, cancellationToken);
    }

    public async Task<List<RoleGroup>> GetAcrossTenantsAsync(int maxRows, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.RequireBoundedLimit(maxRows);
        return await _context.RoleGroups
            .Include(g => g.Tenant)
            .Include(g => g.Roles)
            .AsNoTracking()
            .OrderBy(g => g.Id)
            .Take(maxRows)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<RoleGroup>> GetByTenantIdAsync(Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups
            .Include(g => g.Tenant)
            .Include(g => g.Roles)
            .Where(g => g.TenantId == tenantId)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(RoleGroup group, CancellationToken cancellationToken = default)
        => await _context.RoleGroups.AddAsync(group, cancellationToken);

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups.AnyAsync(g => g.Name == name && g.TenantId == tenantId, cancellationToken);
    }

    public async Task<bool> NameExistsAsync(string name, Guid tenantId, Guid excludeId, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.RoleGroups.AnyAsync(g => g.Name == name && g.TenantId == tenantId && g.Id != excludeId, cancellationToken);
    }

    public void Remove(RoleGroup group) => _context.RoleGroups.Remove(group);
}
