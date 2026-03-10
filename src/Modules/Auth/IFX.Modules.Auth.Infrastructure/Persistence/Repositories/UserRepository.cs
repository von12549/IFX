using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Persistence.Repositories;

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
            .Include(u => u.Identities)
            .FirstOrDefaultAsync(u => u.Id == id, cancellationToken);
    }

    public async Task<User?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default)
    {
        return await _context.Users
            .Include(u => u.UserRole)
            .Include(u => u.Identities)
            .Where(u => u.Identities.Any(ui => ui.Issuer == issuer && EF.Property<string>(ui, "_subject") == subject))
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<User?> GetByEmailAndIdpAsync(string email, Guid idpId, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .Include(u => u.UserRole)
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
            .Include(u => u.UserRole)
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

    public async Task<bool> ExistsAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.Users
            .AnyAsync(u => u.Identities.Any(ui => EF.Property<string>(ui, "_email") == normalizedEmail), cancellationToken);
    }
}
