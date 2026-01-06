using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;

public class UserRepository : IUserRepository
{
    private readonly CognitoDbContext _context;

    public UserRepository(CognitoDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);
    }

    public async Task<User?> GetByCognitoUserIdAsync(string cognitoUserId, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => EF.Property<string>(u, "_cognitoUserId") == cognitoUserId, cancellationToken);
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => EF.Property<string>(u, "_email") == normalizedEmail, cancellationToken);
    }

    public async Task<User?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => u.Username == username, cancellationToken);
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

    public async Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .AnyAsync(u => EF.Property<string>(u, "_email") == normalizedEmail, cancellationToken);
    }
}
