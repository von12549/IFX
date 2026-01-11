using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.RevokeToken;

public class RevokeTokenCommandHandler : IRequestHandler<RevokeTokenCommand, Result<bool>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RevokeTokenCommandHandler> _logger;

    public RevokeTokenCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        ILogger<RevokeTokenCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(
        RevokeTokenCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Revoke token in Cognito
            var revokeSuccess = await _cognitoService.RevokeTokenAsync(request.RefreshToken);

            if (!revokeSuccess)
            {
                _logger.LogWarning("Failed to revoke refresh token");
                return Result<bool>.Failure("Failed to revoke refresh token");
            }

            // If email is provided, create activity log
            if (!string.IsNullOrEmpty(request.Email))
            {
                var user = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
                if (user != null)
                {
                    // Create UserActivityLog
                    var activityLog = UserActivityLog.Create(
                        user.Id,
                        ActivityType.Logout,
                        "Refresh token revoked",
                        request.IpAddress ?? "Unknown");

                    await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
                    await _unitOfWork.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation("Refresh token revoked for user {Email}", request.Email);
                }
            }

            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error revoking refresh token");
            return Result<bool>.Failure("An error occurred while revoking the refresh token");
        }
    }
}
