namespace IFX.Modules.Auth.Application.Identity.Interfaces;

public interface IEmailVerificationCleanupService
{
    Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default);
}
