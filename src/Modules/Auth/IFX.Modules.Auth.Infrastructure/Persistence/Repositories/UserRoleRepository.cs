using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Repositories;

public class UserRoleRepository : IUserRoleRepository
{
    private readonly AuthDbContext _context;

    public UserRoleRepository(AuthDbContext context)
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
