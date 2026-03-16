using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Commands.SendEmailVerification;

public class SendEmailVerificationCommandHandler : IRequestHandler<SendEmailVerificationCommand, Result<EmailVerificationTokenInfo>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IEmailVerificationService _emailVerificationService;
    private readonly ILogger<SendEmailVerificationCommandHandler> _logger;

    private const int TokenValidityMinutes = 60;

    public SendEmailVerificationCommandHandler(
        IUnitOfWork unitOfWork,
        IEmailVerificationService emailVerificationService,
        ILogger<SendEmailVerificationCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _emailVerificationService = emailVerificationService;
        _logger = logger;
    }

    public async Task<Result<EmailVerificationTokenInfo>> Handle(
        SendEmailVerificationCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get UserIdentity
            var userIdentity = await _unitOfWork.UserIdentities.GetByIdAsync(
                request.UserIdentityId, cancellationToken);

            if (userIdentity == null)
            {
                _logger.LogWarning("UserIdentity not found: {UserIdentityId}", request.UserIdentityId);
                return Result<EmailVerificationTokenInfo>.Failure("User identity not found");
            }

            // Check if email is already verified
            if (userIdentity.EmailVerified)
            {
                _logger.LogInformation("Email already verified for UserIdentity: {UserIdentityId}", request.UserIdentityId);
                return Result<EmailVerificationTokenInfo>.Failure("Email is already verified");
            }

            // Validate email exists
            if (string.IsNullOrEmpty(userIdentity.Email?.Value))
            {
                _logger.LogWarning("No email found for UserIdentity: {UserIdentityId}", request.UserIdentityId);
                return Result<EmailVerificationTokenInfo>.Failure("User does not have an email address");
            }

            // Invalidate existing active tokens
            await _unitOfWork.EmailVerificationTokens.InvalidateAllForUserIdentityAsync(
                request.UserIdentityId, cancellationToken);

            // Generate new token and code
            var (token, tokenHash, code) = _emailVerificationService.GenerateVerificationCredentials();

            // Create EmailVerificationToken entity
            var verificationToken = EmailVerificationToken.Create(
                userIdentityId: request.UserIdentityId,
                email: userIdentity.Email.Value,
                tokenHash: tokenHash,
                code: code,
                validityPeriod: TimeSpan.FromMinutes(TokenValidityMinutes));

            await _unitOfWork.EmailVerificationTokens.AddAsync(verificationToken, cancellationToken);

            // Create activity log
            var activityLog = UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerificationSent,
                $"Email verification sent to {userIdentity.Email.Value}",
                request.IpAddress ?? "Unknown");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Email verification token created for UserIdentity: {UserIdentityId}, Email: {Email}",
                request.UserIdentityId, userIdentity.Email.Value);

            return Result<EmailVerificationTokenInfo>.Success(new EmailVerificationTokenInfo(
                TokenId: verificationToken.Id,
                UserIdentityId: request.UserIdentityId,
                Email: userIdentity.Email.Value,
                Token: token,
                Code: code,
                ExpiresAt: verificationToken.ExpiresAt));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending email verification for UserIdentity: {UserIdentityId}", request.UserIdentityId);
            return Result<EmailVerificationTokenInfo>.Failure("An error occurred while sending email verification");
        }
    }
}
