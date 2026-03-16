// Types are in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public interface IEmailVerificationTokenRepository
{
    Task<EmailVerificationToken?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<EmailVerificationToken?> GetByTokenHashAsync(string tokenHash, CancellationToken cancellationToken = default);
    Task<EmailVerificationToken?> GetActiveByCodeAsync(Guid userIdentityId, string code, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<EmailVerificationToken>> GetActiveByUserIdentityIdAsync(Guid userIdentityId, CancellationToken cancellationToken = default);
    Task AddAsync(EmailVerificationToken token, CancellationToken cancellationToken = default);
    Task UpdateAsync(EmailVerificationToken token, CancellationToken cancellationToken = default);
    Task InvalidateAllForUserIdentityAsync(Guid userIdentityId, CancellationToken cancellationToken = default);
    Task DeleteExpiredAsync(CancellationToken cancellationToken = default);
}
