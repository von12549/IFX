using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class UserRoleRepository : IUserRoleRepository
{
    private readonly CognitoDbContext _context;

    public UserRoleRepository(CognitoDbContext context)
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
}
