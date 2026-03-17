using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// Repository interface is in IFX.Modules.Auth.Domain.Identity
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Identity.Repositories;

public class UserIdentityRepository : IUserIdentityRepository
{
    private readonly IfxDbContext _context;

    public UserIdentityRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<UserIdentity?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.UserIdentities
            .Include(ui => ui.User)
                .ThenInclude(u => u!.UserRole)
            .Include(ui => ui.Idp)
            .FirstOrDefaultAsync(ui => ui.Id == id, cancellationToken);
    }

    public async Task<UserIdentity?> GetByIssuerAndSubjectAsync(string issuer, string subject, CancellationToken cancellationToken = default)
    {
        return await _context.UserIdentities
            .Include(ui => ui.User)
                .ThenInclude(u => u!.UserRole)
            .Include(ui => ui.Idp)
            .FirstOrDefaultAsync(
                ui => ui.Issuer == issuer && EF.Property<string>(ui, "_subject") == subject,
                cancellationToken);
    }

    public async Task<UserIdentity?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = email.ToLowerInvariant();
        return await _context.UserIdentities
            .Include(ui => ui.User)
                .ThenInclude(u => u!.UserRole)
            .Include(ui => ui.Idp)
            .FirstOrDefaultAsync(ui => EF.Property<string>(ui, "_email") == normalizedEmail, cancellationToken);
    }

    public async Task<List<UserIdentity>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.UserIdentities
            .Include(ui => ui.Idp)
            .Where(ui => ui.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(UserIdentity userIdentity, CancellationToken cancellationToken = default)
    {
        await _context.UserIdentities.AddAsync(userIdentity, cancellationToken);
    }

    public Task UpdateAsync(UserIdentity userIdentity, CancellationToken cancellationToken = default)
    {
        _context.UserIdentities.Update(userIdentity);
        return Task.CompletedTask;
    }
}
