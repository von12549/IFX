using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Authorization;
// IUserRoleRepository is in IFX.Modules.Auth.Domain.Authorization
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Repositories;

public class UserRoleRepository : IUserRoleRepository
{
    private readonly IfxDbContext _context;

    public UserRoleRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<UserRole?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.UserRoles
            .FirstOrDefaultAsync(r => r.Id == id, cancellationToken);
    }

    public async Task<UserRole?> GetByRoleNameAsync(string roleName, CancellationToken cancellationToken = default)
    {
        return await _context.UserRoles
            .FirstOrDefaultAsync(r => r.RoleName == roleName, cancellationToken);
    }

    public async Task<List<UserRole>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await _context.UserRoles
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(UserRole role, CancellationToken cancellationToken = default)
    {
        await _context.UserRoles.AddAsync(role, cancellationToken);
    }

    public async Task<bool> RoleNameExistsAsync(string roleName, CancellationToken cancellationToken = default)
    {
        return await _context.UserRoles
            .AnyAsync(r => r.RoleName == roleName, cancellationToken);
    }

    public async Task<bool> RoleNameExistsAsync(string roleName, Guid excludeRoleId, CancellationToken cancellationToken = default)
    {
        return await _context.UserRoles
            .AnyAsync(r => r.RoleName == roleName && r.Id != excludeRoleId, cancellationToken);
    }
}
