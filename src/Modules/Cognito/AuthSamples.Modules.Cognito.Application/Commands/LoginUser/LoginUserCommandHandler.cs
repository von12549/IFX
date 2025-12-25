using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.LoginUser;

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
            // Get user from local DB
            var user = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
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

            // Sync user data from Cognito (optional, gets latest attributes)
            try
            {
                var cognitoUserInfo = await _cognitoService.GetUserAsync(authResult.AccessToken!);
                user.UpdateFromCognito(
                    EmailAddress.Create(cognitoUserInfo.Email),
                    cognitoUserInfo.FirstName,
                    cognitoUserInfo.LastName,
                    cognitoUserInfo.PhoneNumber,
                    cognitoUserInfo.EmailVerified,
                    cognitoUserInfo.PhoneNumberVerified);

                await _unitOfWork.Users.UpdateAsync(user, cancellationToken);
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
