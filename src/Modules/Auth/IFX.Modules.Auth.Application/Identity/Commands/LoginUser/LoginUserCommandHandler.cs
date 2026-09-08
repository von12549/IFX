using System.IdentityModel.Tokens.Jwt;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.LoginUser;
public class LoginUserCommandHandler : IRequestHandler<LoginUserCommand, Result<LoginUserResponse>>
{
    private readonly IIdentityProvider _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<LoginUserCommandHandler> _logger;
    public LoginUserCommandHandler(IIdentityProvider identityProvider, IUnitOfWork unitOfWork, IMapper mapper, ILogger<LoginUserCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<LoginUserResponse>> Handle(LoginUserCommand request, CancellationToken cancellationToken)
    {
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
                _logger.LogWarning("Login attempt rejected because the local user was not found");
                return Result<LoginUserResponse>.Failure("Invalid email or password");
            }

            // Authenticate with Cognito (use email as username since Cognito User Pool is configured with email sign-in)
            var authResult = await _identityProvider.AuthenticateAsync(request.Email, request.Password);
            if (!authResult.Success)
            {
                // Create failed login event
                var failedLoginEvent = LoginEvent.CreateFailure(user.Id, request.IpAddress, request.UserAgent, "authentication_failed");
                await _unitOfWork.LoginEvents.AddAsync(failedLoginEvent, cancellationToken);
                _logger.LogWarning("Login attempt rejected by the identity provider");
                return Result<LoginUserResponse>.Failure("Invalid email or password");
            }

            // Extract issuer and subject from IdToken
            var jwtHandler = new JwtSecurityTokenHandler();
            var idToken = jwtHandler.ReadJwtToken(authResult.IdToken!);
            var issuer = idToken.Issuer;
            var subject = idToken.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
            if (string.IsNullOrEmpty(subject))
            {
                _logger.LogError("Identity provider response did not contain a subject claim");
                return Result<LoginUserResponse>.Failure("Authentication failed");
            }

            // Verify user matches the authenticated subject
            var authenticatedUser = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject, cancellationToken);
            if (authenticatedUser == null || authenticatedUser.Id != user.Id)
            {
                _logger.LogWarning("Authenticated identity did not match the local user");
                return Result<LoginUserResponse>.Failure("Authentication failed");
            }

            // Use the authenticated user for subsequent operations
            user = authenticatedUser;
            // Sync user data from Cognito (update UserIdentity)
            {
                var cognitoUserInfo = await _identityProvider.GetUserAsync(authResult.AccessToken!);
                var identity = user.Identities.FirstOrDefault(i => i.Issuer == issuer && i.Subject.Value == subject);
                if (identity != null)
                {
                    identity.UpdateFromIdp(EmailAddress.Create(cognitoUserInfo.Email), cognitoUserInfo.FirstName, cognitoUserInfo.LastName, cognitoUserInfo.PhoneNumber, cognitoUserInfo.EmailVerified, cognitoUserInfo.PhoneNumberVerified);
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

            // Tokens are returned to the caller only and are never persisted in audit history.
            var loginEvent = LoginEvent.CreateSuccess(user.Id, request.IpAddress, request.UserAgent);
            await _unitOfWork.LoginEvents.AddAsync(loginEvent, cancellationToken);
            // Create activity log
            var activityLog = UserActivityLog.Create(user.Id, ActivityType.Login, "User login succeeded", request.IpAddress);
            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            _logger.LogInformation("User login succeeded");
            // Map user to DTO
            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<LoginUserResponse>.Success(new LoginUserResponse { AccessToken = authResult.AccessToken!, RefreshToken = authResult.RefreshToken!, IdToken = authResult.IdToken!, ExpiresIn = authResult.ExpiresIn, UserProfile = userProfile });
        }
    }
}
