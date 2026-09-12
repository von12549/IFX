using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Services;

public sealed class EmailVerificationIssuanceService(
    IUnitOfWork unitOfWork,
    IEmailVerificationService emailVerificationService,
    ILogger<EmailVerificationIssuanceService> logger) : IEmailVerificationIssuanceService
{
    private const int TokenValidityMinutes = 60;

    public async Task<Result<EmailVerificationTokenInfo>> IssueAsync(
        Guid userIdentityId,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        var userIdentity = await unitOfWork.UserIdentities.GetByIdAsync(userIdentityId, cancellationToken);
        if (userIdentity is null)
        {
            logger.LogWarning("UserIdentity not found: {UserIdentityId}", userIdentityId);
            return Result<EmailVerificationTokenInfo>.Failure("User identity not found");
        }

        if (userIdentity.EmailVerified)
        {
            return Result<EmailVerificationTokenInfo>.Failure("Email is already verified");
        }

        if (string.IsNullOrEmpty(userIdentity.Email?.Value))
        {
            return Result<EmailVerificationTokenInfo>.Failure("User does not have an email address");
        }

        await unitOfWork.EmailVerificationTokens.InvalidateAllForUserIdentityAsync(
            userIdentityId,
            cancellationToken);
        var (token, tokenHash, code) = emailVerificationService.GenerateVerificationCredentials();
        var verificationToken = EmailVerificationToken.Create(
            userIdentityId,
            userIdentity.Email.Value,
            tokenHash,
            code,
            TimeSpan.FromMinutes(TokenValidityMinutes));
        await unitOfWork.EmailVerificationTokens.AddAsync(verificationToken, cancellationToken);

        var activityLog = UserActivityLog.Create(
            userIdentity.UserId,
            ActivityType.EmailVerificationSent,
            $"Email verification sent to {userIdentity.Email.Value}",
            ipAddress ?? "Unknown");
        await unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

        return Result<EmailVerificationTokenInfo>.Success(new EmailVerificationTokenInfo(
            verificationToken.Id,
            userIdentityId,
            userIdentity.Email.Value,
            token,
            code,
            verificationToken.ExpiresAt));
    }
}
