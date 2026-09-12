using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Commands.LogoutUser;
public class LogoutUserCommandHandler : IRequestHandler<LogoutUserCommand, Result<bool>>
{
    private readonly ITokenLifecycleService _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<LogoutUserCommandHandler> _logger;
    public LogoutUserCommandHandler(ITokenLifecycleService identityProvider, IUnitOfWork unitOfWork, ILogger<LogoutUserCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(LogoutUserCommand request, CancellationToken cancellationToken)
    {
        {
            // Get user by Issuer and Subject
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<bool>.Failure("User not found");
            }

            // Sign out from Cognito
            var signedOut = await _identityProvider.SignOutAsync(request.AccessToken);
            if (!signedOut)
            {
                _logger.LogWarning("Identity provider sign-out failed");
            }

            // Get the most recent successful login to calculate session duration
            var loginHistory = await _unitOfWork.LoginEvents.GetUserLoginHistoryAsync(user.Id, 1, 1, cancellationToken);
            var lastLogin = loginHistory.FirstOrDefault();
            var loginTimestamp = lastLogin?.LoginTimestamp ?? DateTimeOffset.UtcNow;
            // Create logout event with session duration
            var logoutEvent = LogoutEvent.Create(user.Id, request.IpAddress, loginTimestamp, "Manual");
            await _unitOfWork.LogoutEvents.AddAsync(logoutEvent, cancellationToken);
            // Create activity log
            var activityLog = UserActivityLog.Create(user.Id, ActivityType.Logout, "User logout completed", request.IpAddress, $"{{\"sessionDuration\": \"{logoutEvent.SessionDuration}\"}}");
            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            _logger.LogInformation("User logout completed in {Duration}", logoutEvent.SessionDuration);
            return Result<bool>.Success(true);
        }
    }
}
