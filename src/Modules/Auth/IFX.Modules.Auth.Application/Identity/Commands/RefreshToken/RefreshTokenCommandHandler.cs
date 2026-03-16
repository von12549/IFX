using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Commands.RefreshToken;

public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, Result<RefreshTokenResponse>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<RefreshTokenCommandHandler> _logger;

    public RefreshTokenCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<RefreshTokenCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RefreshTokenResponse>> Handle(
        RefreshTokenCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Refresh token with Cognito
            var cognitoResult = await _cognitoService.RefreshTokenAsync(request.RefreshToken, request.Username);

            if (!cognitoResult.Success)
            {
                _logger.LogWarning("Failed to refresh token: {ErrorMessage}", cognitoResult.ErrorMessage);
                return Result<RefreshTokenResponse>.Failure(
                    cognitoResult.ErrorMessage ?? "Failed to refresh token");
            }

            // Get user info from Cognito using the new access token
            var cognitoUserInfo = await _cognitoService.GetUserAsync(cognitoResult.AccessToken!);
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
                _logger.LogWarning("User not found for Issuer {Issuer} and Subject {Subject}", primaryIdp.Issuer, subject);
                return Result<RefreshTokenResponse>.Failure("User not found");
            }

            // Create new LoginEvent for token refresh
            var loginEvent = LoginEvent.CreateSuccess(
                user.Id,
                request.IpAddress ?? "Unknown",
                "Token Refresh", // DeviceInfo not available on refresh
                cognitoSessionId: null,
                cognitoResult.AccessToken,
                cognitoResult.RefreshToken,
                DateTime.UtcNow.AddSeconds(cognitoResult.ExpiresIn));

            await _unitOfWork.LoginEvents.AddAsync(loginEvent, cancellationToken);

            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Login,
                $"Token refreshed for user {user.DisplayName}",
                request.IpAddress ?? "Unknown");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Token refreshed successfully for Subject {Subject}", subject);

            // Map user to DTO
            var userProfileDto = _mapper.Map<UserProfileDto>(user);

            return Result<RefreshTokenResponse>.Success(new RefreshTokenResponse
            {
                AccessToken = cognitoResult.AccessToken,
                IdToken = cognitoResult.IdToken,
                RefreshToken = cognitoResult.RefreshToken,
                ExpiresIn = cognitoResult.ExpiresIn,
                TokenType = cognitoResult.TokenType,
                ExpiresAt = DateTime.UtcNow.AddSeconds(cognitoResult.ExpiresIn),
                UserProfile = userProfileDto
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing token");
            return Result<RefreshTokenResponse>.Failure("An error occurred while refreshing the token");
        }
    }
}
