using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Commands.VerifyEmail;

public class VerifyEmailCommandHandler : IRequestHandler<VerifyEmailCommand, Result<VerifyEmailResponse>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IEmailVerificationService _emailVerificationService;
    private readonly ILogger<VerifyEmailCommandHandler> _logger;

    public VerifyEmailCommandHandler(
        IUnitOfWork unitOfWork,
        IEmailVerificationService emailVerificationService,
        ILogger<VerifyEmailCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _emailVerificationService = emailVerificationService;
        _logger = logger;
    }

    public async Task<Result<VerifyEmailResponse>> Handle(
        VerifyEmailCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Validate that either token or code is provided
            if (string.IsNullOrEmpty(request.Token) && string.IsNullOrEmpty(request.Code))
            {
                return Result<VerifyEmailResponse>.Failure("Either verification token or code is required");
            }

            // Get UserIdentity
            var userIdentity = await _unitOfWork.UserIdentities.GetByIdAsync(
                request.UserIdentityId, cancellationToken);

            if (userIdentity == null)
            {
                _logger.LogWarning("UserIdentity not found: {UserIdentityId}", request.UserIdentityId);
                return Result<VerifyEmailResponse>.Failure("Invalid verification request");
            }

            // Check if already verified
            if (userIdentity.EmailVerified)
            {
                return Result<VerifyEmailResponse>.Success(new VerifyEmailResponse(
                    Success: true,
                    Message: "Email is already verified"));
            }

            // Find the verification token
            EmailVerificationToken? verificationToken = null;

            if (!string.IsNullOrEmpty(request.Token))
            {
                // Verify by token hash
                var tokenHash = _emailVerificationService.HashToken(request.Token);
                verificationToken = await _unitOfWork.EmailVerificationTokens.GetByTokenHashAsync(
                    tokenHash, cancellationToken);

                // Validate token belongs to the right user identity
                if (verificationToken != null && verificationToken.UserIdentityId != request.UserIdentityId)
                {
                    _logger.LogWarning(
                        "Token mismatch: Token belongs to {TokenUserIdentityId}, but request is for {RequestUserIdentityId}",
                        verificationToken.UserIdentityId, request.UserIdentityId);
                    verificationToken = null;
                }
            }
            else if (!string.IsNullOrEmpty(request.Code))
            {
                // Verify by code
                verificationToken = await _unitOfWork.EmailVerificationTokens.GetActiveByCodeAsync(
                    request.UserIdentityId, request.Code, cancellationToken);
            }

            if (verificationToken == null)
            {
                _logger.LogWarning(
                    "Invalid verification attempt for UserIdentity: {UserIdentityId}",
                    request.UserIdentityId);

                // Log failed attempt
                var failedLog = UserActivityLog.Create(
                    userIdentity.UserId,
                    ActivityType.EmailVerificationFailed,
                    "Invalid verification token or code",
                    request.IpAddress ?? "Unknown");

                await _unitOfWork.UserActivityLogs.AddAsync(failedLog, cancellationToken);
                await _unitOfWork.SaveChangesAsync(cancellationToken);

                return Result<VerifyEmailResponse>.Failure("Invalid or expired verification token/code");
            }

            // Check if token is valid
            if (!verificationToken.IsValid())
            {
                _logger.LogWarning(
                    "Expired or used token for UserIdentity: {UserIdentityId}",
                    request.UserIdentityId);

                return Result<VerifyEmailResponse>.Failure("Verification token has expired or already been used");
            }

            // Mark token as used
            verificationToken.MarkAsUsed();
            await _unitOfWork.EmailVerificationTokens.UpdateAsync(verificationToken, cancellationToken);

            // Update UserIdentity.EmailVerified
            userIdentity.UpdateFromIdp(
                email: userIdentity.Email,
                firstName: userIdentity.FirstName,
                lastName: userIdentity.LastName,
                phoneNumber: userIdentity.PhoneNumber,
                emailVerified: true,
                phoneNumberVerified: userIdentity.PhoneNumberVerified);

            await _unitOfWork.UserIdentities.UpdateAsync(userIdentity, cancellationToken);

            // Create activity log
            var activityLog = UserActivityLog.Create(
                userIdentity.UserId,
                ActivityType.EmailVerified,
                $"Email verified: {userIdentity.Email.Value}",
                request.IpAddress ?? "Unknown");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Email verified successfully for UserIdentity: {UserIdentityId}, Email: {Email}",
                request.UserIdentityId, userIdentity.Email.Value);

            return Result<VerifyEmailResponse>.Success(new VerifyEmailResponse(
                Success: true,
                Message: "Email verified successfully"));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying email for UserIdentity: {UserIdentityId}", request.UserIdentityId);
            return Result<VerifyEmailResponse>.Failure("An error occurred while verifying email");
        }
    }
}
