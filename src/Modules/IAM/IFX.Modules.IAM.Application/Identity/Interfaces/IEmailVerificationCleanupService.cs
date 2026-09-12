namespace IFX.Modules.IAM.Application.Identity.Interfaces;

public interface IEmailVerificationCleanupService
{
    Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default);
}
