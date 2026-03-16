using IFX.Modules.Auth.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Infrastructure.Services;

public class EmailVerificationCleanupService : IEmailVerificationCleanupService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<EmailVerificationCleanupService> _logger;

    public EmailVerificationCleanupService(
        IUnitOfWork unitOfWork,
        ILogger<EmailVerificationCleanupService> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting email verification token cleanup...");

            await _unitOfWork.EmailVerificationTokens.DeleteExpiredAsync(cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Email verification token cleanup completed successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during email verification token cleanup");
            throw;
        }
    }
}
