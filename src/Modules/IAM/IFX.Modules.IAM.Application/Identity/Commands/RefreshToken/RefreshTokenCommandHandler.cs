using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Commands.RefreshToken;
public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, Result<RefreshTokenResponse>>
{
    private readonly IIdentityProvider _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<RefreshTokenCommandHandler> _logger;
    public RefreshTokenCommandHandler(IIdentityProvider identityProvider, IUnitOfWork unitOfWork, IMapper mapper, ILogger<RefreshTokenCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RefreshTokenResponse>> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        {
            // Refresh token with Cognito
            var cognitoResult = await _identityProvider.RefreshTokenAsync(request.RefreshToken, request.Username);
            if (!cognitoResult.Success)
            {
                _logger.LogWarning("Token refresh was rejected by the identity provider");
                return Result<RefreshTokenResponse>.Failure("Failed to refresh token");
            }

            // Get user info from Cognito using the new access token
            var cognitoUserInfo = await _identityProvider.GetUserAsync(cognitoResult.AccessToken!);
            var subject = cognitoUserInfo.Subject;
            if (string.IsNullOrEmpty(subject))
            {
                _logger.LogError("Subject not found in Cognito user info");
                return Result<RefreshTokenResponse>.Failure("Invalid token response");
            }

            // Get primary IdP and user from database
            var primaryIdp = await _unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
            if (primaryIdp == null)
            {
                _logger.LogError("Primary IdP not found or not enabled in database");
                return Result<RefreshTokenResponse>.Failure("System configuration error. Please contact support.");
            }

            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(primaryIdp.Issuer, subject, cancellationToken);
            if (user == null)
            {
                _logger.LogWarning("Token refresh identity did not match a local user");
                return Result<RefreshTokenResponse>.Failure("User not found");
            }

            // Record the outcome only; refreshed credentials never enter persistence.
            var loginEvent = LoginEvent.CreateSuccess(user.Id, request.IpAddress ?? "Unknown", "Token Refresh");
            await _unitOfWork.LoginEvents.AddAsync(loginEvent, cancellationToken);
            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(user.Id, ActivityType.Login, "Token refresh succeeded", request.IpAddress ?? "Unknown");
            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            _logger.LogInformation("Token refresh succeeded");
            // Map user to DTO
            var userProfileDto = _mapper.Map<UserProfileDto>(user);
            return Result<RefreshTokenResponse>.Success(new RefreshTokenResponse { AccessToken = cognitoResult.AccessToken, IdToken = cognitoResult.IdToken, RefreshToken = cognitoResult.RefreshToken, ExpiresIn = cognitoResult.ExpiresIn, TokenType = cognitoResult.TokenType, ExpiresAt = DateTime.UtcNow.AddSeconds(cognitoResult.ExpiresIn), UserProfile = userProfileDto });
        }
    }
}
