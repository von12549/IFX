using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Users;
using IFX.BuildingBlocks.EntityFrameworkCore;
// Repository interface is in same namespace (IFX.Modules.Auth.Domain.Users)
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Users.Repositories;

public class UserRepository : IUserRepository
{
    private readonly IfxDbContext _context;

    public UserRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Users
            .Include(u => u.Identities)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public async Task<User?> GetByIdWithTenantsAndDepartmentsAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Users
            .Include(u => u.Tenants)
            .Include(u => u.Departments)
            .Include(u => u.Identities)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public async Task<User?> GetByIdWithRolesAndGroupsAsync(Guid id, CancellationToken cancellationToken = default)
        => await _context.Users
            .Include(u => u.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.RoleGroups).ThenInclude(g => g.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.Identities)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public async Task<User?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default)
        => await _context.Users
            .Include(u => u.Identities)
            .Where(u => u.Identities.Any(ui => ui.Issuer == issuer && EF.Property<string>(ui, "_subject") == subject))
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<User?> GetByIssuerAndSubjectWithPermissionsAsync(string issuer, string subject, CancellationToken cancellationToken = default)
        => await _context.Users
            .Include(u => u.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.RoleGroups).ThenInclude(g => g.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.Identities)
            .Include(u => u.Tenants)
            .Include(u => u.Departments).ThenInclude(d => d.Tenant)
            .Include(u => u.GlobalRoles).ThenInclude(ugr => ugr.GlobalRole)
            .Where(u => u.Identities.Any(ui => ui.Issuer == issuer && EF.Property<string>(ui, "_subject") == subject))
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<User?> GetByEmailAndIdpAsync(string email, Guid idpId, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .Include(u => u.Identities)
            .Where(u => u.Identities.Any(ui =>
                EF.Property<string>(ui, "_email") == normalizedEmail &&
                ui.IdpId == idpId))
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task AddAsync(User user, CancellationToken cancellationToken = default)
    {
        await _context.Users.AddAsync(user, cancellationToken);
    }

    public Task UpdateAsync(User user, CancellationToken cancellationToken = default)
    {
        _context.Users.Update(user);
        return Task.CompletedTask;
    }

    public async Task<(List<User> Users, int TotalCount)> GetAllUsersAsync(
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = _context.Users
            .Include(u => u.Roles)
            .Include(u => u.RoleGroups).ThenInclude(g => g.Roles)
            .Include(u => u.Identities)
            .AsNoTracking();

        var totalCount = await query.CountAsync(cancellationToken);

        var users = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (users, totalCount);
    }

    public async Task<(List<User> Users, int TotalCount)> GetAllUsersByTenantAsync(
        Guid tenantId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.Require(tenantId);
        var query = _context.Users
            .Include(u => u.Roles)
            .Include(u => u.RoleGroups).ThenInclude(g => g.Roles)
            .Include(u => u.Identities)
            .Include(u => u.Tenants)
            .Where(u => u.Tenants.Any(t => t.Id == tenantId))
            .AsNoTracking();

        var totalCount = await query.CountAsync(cancellationToken);

        var users = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (users, totalCount);
    }

    public async Task<List<User>> GetAcrossTenantsWithTenantsAsync(int maxRows, CancellationToken cancellationToken = default)
    {
        TenantQueryGuard.RequireBoundedLimit(maxRows);
        return await _context.Users
            .Include(u => u.Tenants)
            .Include(u => u.Identities)
            .AsNoTracking()
            .OrderBy(u => u.Id)
            .Take(maxRows)
            .ToListAsync(cancellationToken);
    }

    public async Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .AnyAsync(u => u.Identities.Any(ui => EF.Property<string>(ui, "_email") == normalizedEmail), cancellationToken);
    }
}
