using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.RevokeToken;
public class RevokeTokenCommandHandler : IRequestHandler<RevokeTokenCommand, Result<bool>>
{
    private readonly IIdentityProvider _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RevokeTokenCommandHandler> _logger;
    public RevokeTokenCommandHandler(IIdentityProvider identityProvider, IUnitOfWork unitOfWork, ILogger<RevokeTokenCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RevokeTokenCommand request, CancellationToken cancellationToken)
    {
        {
            // Revoke token in Cognito
            var revokeSuccess = await _identityProvider.RevokeTokenAsync(request.RefreshToken);
            if (!revokeSuccess)
            {
                _logger.LogWarning("Failed to revoke refresh token");
                return Result<bool>.Failure("Failed to revoke refresh token");
            }

            // Get primary IdP
            var primaryIdp = await _unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
            if (primaryIdp == null)
            {
                _logger.LogError("Primary IdP not found or not enabled in database");
                return Result<bool>.Failure("System configuration error. Please contact support.");
            }

            // If email is provided, create activity log
            if (!string.IsNullOrEmpty(request.Email))
            {
                var user = await _unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, primaryIdp.Id, cancellationToken);
                if (user != null)
                {
                    // Create UserActivityLog
                    var activityLog = UserActivityLog.Create(user.Id, ActivityType.Logout, "Refresh token revoked", request.IpAddress ?? "Unknown");
                    await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
                    _logger.LogInformation("Refresh token revoked for user {Email}", request.Email);
                }
            }

            return Result<bool>.Success(true);
        }
    }
}
