using IFX.Modules.Auth.Application.Identity.Commands.SendEmailVerification;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.ResendEmailVerification;

public class ResendEmailVerificationCommandHandler : IRequestHandler<ResendEmailVerificationCommand, Result<EmailVerificationTokenInfo>>
{
    private readonly IMediator _mediator;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ResendEmailVerificationCommandHandler> _logger;

    private const int MaxResendsPerHour = 3;

    public ResendEmailVerificationCommandHandler(
        IMediator mediator,
        IUnitOfWork unitOfWork,
        ILogger<ResendEmailVerificationCommandHandler> logger)
    {
        _mediator = mediator;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<EmailVerificationTokenInfo>> Handle(
        ResendEmailVerificationCommand request,
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

            // Check if already verified
            if (userIdentity.EmailVerified)
            {
                return Result<EmailVerificationTokenInfo>.Failure("Email is already verified");
            }

            // Check rate limiting - count recent activity logs
            var recentActivities = await GetRecentVerificationSentCountAsync(
                userIdentity.UserId, TimeSpan.FromHours(1), cancellationToken);

            if (recentActivities >= MaxResendsPerHour)
            {
                _logger.LogWarning(
                    "Rate limit exceeded for UserIdentity: {UserIdentityId}. Sent {Count} in last hour.",
                    request.UserIdentityId, recentActivities);

                return Result<EmailVerificationTokenInfo>.Failure(
                    $"Too many verification emails sent. Please wait before requesting another. Maximum {MaxResendsPerHour} per hour.");
            }

            // Delegate to SendEmailVerificationCommand
            var sendCommand = new SendEmailVerificationCommand(
                request.UserIdentityId,
                request.IpAddress);

            var result = await _mediator.Send(sendCommand, cancellationToken);

            if (!result.IsSuccess)
            {
                return Result<EmailVerificationTokenInfo>.Failure(result.Error!);
            }

            _logger.LogInformation(
                "Resent email verification for UserIdentity: {UserIdentityId}",
                request.UserIdentityId);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resending email verification for UserIdentity: {UserIdentityId}", request.UserIdentityId);
            return Result<EmailVerificationTokenInfo>.Failure("An error occurred while resending email verification");
        }
    }

    private async Task<int> GetRecentVerificationSentCountAsync(
        Guid userId,
        TimeSpan timeSpan,
        CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow - timeSpan;
        var activities = await _unitOfWork.UserActivityLogs.GetUserActivitiesAsync(
            userId, 1, 100, cancellationToken);

        return activities.Count(a =>
            a.ActivityType == ActivityType.EmailVerificationSent &&
            a.Timestamp >= cutoff);
    }
}
