using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Domain.Identity;
// IEmailVerificationTokenRepository is in IFX.Modules.Auth.Domain.Identity
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Users.Repositories;

public class EmailVerificationTokenRepository : IEmailVerificationTokenRepository
{
    private readonly AuthDbContext _context;

    public EmailVerificationTokenRepository(AuthDbContext context)
    {
        _context = context;
    }

    public async Task<EmailVerificationToken?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.EmailVerificationTokens
            .FirstOrDefaultAsync(t => t.Id == id, cancellationToken);
    }

    public async Task<EmailVerificationToken?> GetByTokenHashAsync(string tokenHash, CancellationToken cancellationToken = default)
    {
        return await _context.EmailVerificationTokens
            .FirstOrDefaultAsync(t => t.TokenHash == tokenHash, cancellationToken);
    }

    public async Task<EmailVerificationToken?> GetActiveByCodeAsync(Guid userIdentityId, string code, CancellationToken cancellationToken = default)
    {
        return await _context.EmailVerificationTokens
            .FirstOrDefaultAsync(t =>
                t.UserIdentityId == userIdentityId &&
                t.Code == code &&
                !t.IsUsed &&
                t.ExpiresAt > DateTime.UtcNow,
                cancellationToken);
    }

    public async Task<IReadOnlyList<EmailVerificationToken>> GetActiveByUserIdentityIdAsync(Guid userIdentityId, CancellationToken cancellationToken = default)
    {
        return await _context.EmailVerificationTokens
            .Where(t =>
                t.UserIdentityId == userIdentityId &&
                !t.IsUsed &&
                t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(EmailVerificationToken token, CancellationToken cancellationToken = default)
    {
        await _context.EmailVerificationTokens.AddAsync(token, cancellationToken);
    }

    public Task UpdateAsync(EmailVerificationToken token, CancellationToken cancellationToken = default)
    {
        _context.EmailVerificationTokens.Update(token);
        return Task.CompletedTask;
    }

    public async Task InvalidateAllForUserIdentityAsync(Guid userIdentityId, CancellationToken cancellationToken = default)
    {
        var activeTokens = await _context.EmailVerificationTokens
            .Where(t => t.UserIdentityId == userIdentityId && !t.IsUsed)
            .ToListAsync(cancellationToken);

        foreach (var token in activeTokens)
        {
            token.Invalidate();
        }
    }

    public async Task DeleteExpiredAsync(CancellationToken cancellationToken = default)
    {
        var expiredTokens = await _context.EmailVerificationTokens
            .Where(t => t.ExpiresAt < DateTime.UtcNow && t.IsUsed)
            .ToListAsync(cancellationToken);

        _context.EmailVerificationTokens.RemoveRange(expiredTokens);
    }
}
