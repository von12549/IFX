using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.LogoutUser;

public class LogoutUserCommandHandler : IRequestHandler<LogoutUserCommand, Result<bool>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<LogoutUserCommandHandler> _logger;

    public LogoutUserCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        ILogger<LogoutUserCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(
        LogoutUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get user by CognitoUserId
            var user = await _unitOfWork.Users.GetByCognitoUserIdAsync(request.CognitoUserId, cancellationToken);
            if (user == null)
            {
                return Result<bool>.Failure("User not found");
            }

            // Sign out from Cognito
            var signedOut = await _cognitoService.SignOutAsync(request.AccessToken);
            if (!signedOut)
            {
                _logger.LogWarning("Failed to sign out user {CognitoUserId} from Cognito", request.CognitoUserId);
            }

            // Get the most recent successful login to calculate session duration
            var loginHistory = await _unitOfWork.LoginEvents.GetUserLoginHistoryAsync(user.Id, 1, 1, cancellationToken);
            var lastLogin = loginHistory.FirstOrDefault();
            var loginTimestamp = lastLogin?.LoginTimestamp ?? DateTime.UtcNow;

            // Create logout event with session duration
            var logoutEvent = LogoutEvent.Create(
                user.Id,
                request.IpAddress,
                loginTimestamp,
                "Manual");

            await _unitOfWork.LogoutEvents.AddAsync(logoutEvent, cancellationToken);

            // Create activity log
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Logout,
                $"User logged out from {request.IpAddress}",
                request.IpAddress,
                $"{{\"sessionDuration\": \"{logoutEvent.SessionDuration}\"}}");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "User {CognitoUserId} logged out successfully. Session duration: {Duration}",
                request.CognitoUserId,
                logoutEvent.SessionDuration);

            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout for user {CognitoUserId}", request.CognitoUserId);
            return Result<bool>.Failure("An error occurred during logout");
        }
    }
}
