using System.IdentityModel.Tokens.Jwt;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using IFX.Modules.Auth.Domain.ValueObjects;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Commands.LoginUser;

public class LoginUserCommandHandler : IRequestHandler<LoginUserCommand, Result<LoginUserResponse>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<LoginUserCommandHandler> _logger;

    public LoginUserCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<LoginUserCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<LoginUserResponse>> Handle(
        LoginUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get primary IdP
            var primaryIdp = await _unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
            if (primaryIdp == null)
            {
                _logger.LogError("Primary IdP not found or not enabled in database");
                return Result<LoginUserResponse>.Failure("System configuration error. Please contact support.");
            }
            // Get user from local DB
            var user = await _unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, primaryIdp.Id, cancellationToken);
            if (user == null)
            {
                // Create failed login event for unknown user
                _logger.LogWarning("Login attempt for non-existent user {Email}", request.Email);
                return Result<LoginUserResponse>.Failure("Invalid email or password");
            }

            // Authenticate with Cognito (use email as username since Cognito User Pool is configured with email sign-in)
            var authResult = await _cognitoService.AuthenticateAsync(request.Email, request.Password);

            if (!authResult.Success)
            {
                // Create failed login event
                var failedLoginEvent = LoginEvent.CreateFailure(
                    user.Id,
                    request.IpAddress,
                    request.UserAgent,
                    authResult.ErrorMessage ?? "Authentication failed");

                await _unitOfWork.LoginEvents.AddAsync(failedLoginEvent, cancellationToken);
                await _unitOfWork.SaveChangesAsync(cancellationToken);

                _logger.LogWarning(
                    "Failed login attempt for user {Email}: {Reason}",
                    request.Email,
                    authResult.ErrorMessage);

                return Result<LoginUserResponse>.Failure(authResult.ErrorMessage ?? "Invalid email or password");
            }

            // Extract issuer and subject from IdToken
            var jwtHandler = new JwtSecurityTokenHandler();
            var idToken = jwtHandler.ReadJwtToken(authResult.IdToken!);
            var issuer = idToken.Issuer;
            var subject = idToken.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;

            if (string.IsNullOrEmpty(subject))
            {
                _logger.LogError("Subject claim not found in IdToken for user {Email}", request.Email);
                return Result<LoginUserResponse>.Failure("Authentication failed");
            }

            // Verify user matches the authenticated subject
            var authenticatedUser = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject, cancellationToken);
            if (authenticatedUser == null || authenticatedUser.Id != user.Id)
            {
                _logger.LogWarning("User mismatch: DB user {UserId} vs authenticated user {Subject}", user.Id, subject);
                return Result<LoginUserResponse>.Failure("Authentication failed");
            }

            // Use the authenticated user for subsequent operations
            user = authenticatedUser;

            // Sync user data from Cognito (update UserIdentity)
            try
            {
                var cognitoUserInfo = await _cognitoService.GetUserAsync(authResult.AccessToken!);
                var identity = user.Identities.FirstOrDefault(i => i.Issuer == issuer && i.Subject.Value == subject);

                if (identity != null)
                {
                    identity.UpdateFromIdp(
                        EmailAddress.Create(cognitoUserInfo.Email),
                        cognitoUserInfo.FirstName,
                        cognitoUserInfo.LastName,
                        cognitoUserInfo.PhoneNumber,
                        cognitoUserInfo.EmailVerified,
                        cognitoUserInfo.PhoneNumberVerified);

                    // Update DisplayName if name changed
                    var newDisplayName = $"{cognitoUserInfo.FirstName} {cognitoUserInfo.LastName}";
                    if (user.DisplayName != newDisplayName)
                    {
                        user.UpdateDisplayName(newDisplayName);
                    }

                    await _unitOfWork.UserIdentities.UpdateAsync(identity, cancellationToken);
                    await _unitOfWork.Users.UpdateAsync(user, cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to sync user data from Cognito for {Email}", request.Email);
                // Continue with login even if sync fails
            }

            // Create successful login event with tokens
            var tokenExpiresAt = DateTime.UtcNow.AddSeconds(authResult.ExpiresIn);
            var loginEvent = LoginEvent.CreateSuccess(
                user.Id,
                request.IpAddress,
                request.UserAgent,
                cognitoSessionId: null,
                accessToken: authResult.AccessToken,
                refreshToken: authResult.RefreshToken,
                tokenExpiresAt: tokenExpiresAt);

            await _unitOfWork.LoginEvents.AddAsync(loginEvent, cancellationToken);

            // Create activity log
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Login,
                $"User logged in from {request.IpAddress}",
                request.IpAddress);

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("User {Email} logged in successfully", request.Email);

            // Map user to DTO
            var userProfile = _mapper.Map<UserProfileDto>(user);

            return Result<LoginUserResponse>.Success(new LoginUserResponse
            {
                AccessToken = authResult.AccessToken!,
                RefreshToken = authResult.RefreshToken!,
                IdToken = authResult.IdToken!,
                ExpiresIn = authResult.ExpiresIn,
                UserProfile = userProfile
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during login for {Email}", request.Email);
            return Result<LoginUserResponse>.Failure("An error occurred during login");
        }
    }
}
