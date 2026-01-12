using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Repositories;

public class UserRepository : IUserRepository
{
    private readonly AuthDbContext _context;

    public UserRepository(AuthDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);
    }

    public async Task<User?> GetBySubjectAsync(string subject, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .FirstOrDefaultAsync(u => EF.Property<string>(u, "_subject") == subject, cancellationToken);
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

    public async Task<(List<User> Users, int TotalCount)> GetAllUsersAsync(
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = _context.Users
            .Include(u => u.UserRole)
            .AsNoTracking();

        var totalCount = await query.CountAsync(cancellationToken);

        var users = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (users, totalCount);
    }

    public async Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .AnyAsync(u => EF.Property<string>(u, "_email") == normalizedEmail, cancellationToken);
    }
}
