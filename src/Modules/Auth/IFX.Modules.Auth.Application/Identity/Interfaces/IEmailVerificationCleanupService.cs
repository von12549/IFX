namespace IFX.Modules.Auth.Application.Interfaces;

public interface IEmailVerificationCleanupService
{
    Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default);
}
