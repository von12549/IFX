using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.Enums;
using AuthSamples.Modules.Auth.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.RegisterUser;

public class RegisterUserCommandHandler : IRequestHandler<RegisterUserCommand, Result<RegisterUserResponse>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RegisterUserCommandHandler> _logger;

    public RegisterUserCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        ILogger<RegisterUserCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<RegisterUserResponse>> Handle(
        RegisterUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get IFX Cognito IdP
            const string ifxCognitoIssuer = "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P";
            var ifxCognitoIdp = await _unitOfWork.Idps.GetByIssuerAsync(ifxCognitoIssuer, cancellationToken);
            if (ifxCognitoIdp == null)
            {
                _logger.LogError("IFX Cognito IdP not found in database");
                return Result<RegisterUserResponse>.Failure("System configuration error. Please contact support.");
            }
            // Check if user already exists
            var existingUser = await _unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, ifxCognitoIdp.Id, cancellationToken);
            if (existingUser != null)
            {
                return Result<RegisterUserResponse>.Failure("User with this email already exists");
            }

            // Create user in Cognito
            var cognitoResult = await _cognitoService.SignUpAsync(
                request.Email,
                request.Password,
                request.Username,
                request.FirstName,
                request.LastName,
                request.BirthDate,
                request.PhoneNumber);

            if (!cognitoResult.Success)
            {
                return Result<RegisterUserResponse>.Failure(
                    cognitoResult.ErrorMessage ?? "Failed to create user in Cognito");
            }

            // Get default "User" role
            var userRole = await _unitOfWork.UserRoles.GetByRoleNameAsync("User", cancellationToken);
            if (userRole == null)
            {
                _logger.LogError("Default 'User' role not found in database");
                return Result<RegisterUserResponse>.Failure("System configuration error. Please contact support.");
            }

            

            // Create User entity (simplified structure)
            var displayName = $"{request.FirstName} {request.LastName}";
            var user = User.Create(
                userRoleId: userRole.Id,
                displayName: displayName,
                isActive: false); // Will be activated after confirmation

            await _unitOfWork.Users.AddAsync(user, cancellationToken);

            // Create UserIdentity entity (all identity data)
            var userIdentity = UserIdentity.Create(
                userId: user.Id,
                idpId: ifxCognitoIdp.Id,
                issuer: ifxCognitoIssuer,
                subject: Subject.Create(cognitoResult.Subject!),
                email: EmailAddress.Create(request.Email),
                firstName: request.FirstName,
                lastName: request.LastName,
                birthDate: request.BirthDate,
                phoneNumber: request.PhoneNumber,
                emailVerified: cognitoResult.UserConfirmed,
                phoneNumberVerified: false);

            await _unitOfWork.UserIdentities.AddAsync(userIdentity, cancellationToken);

            // Create RegistrationFlowEvent
            var registrationEvent = RegistrationFlowEvent.Create(
                request.Email,
                request.Username,
                request.IpAddress);

            await _unitOfWork.RegistrationFlowEvents.AddAsync(registrationEvent, cancellationToken);

            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Registration,
                $"User {request.Username} registered",
                request.IpAddress);

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "User {Username} registered successfully with Subject {Subject}",
                request.Username,
                cognitoResult.Subject);

            return Result<RegisterUserResponse>.Success(new RegisterUserResponse
            {
                UserId = user.Id,
                Subject = cognitoResult.Subject!,
                RequiresConfirmation = !cognitoResult.UserConfirmed,
                Message = cognitoResult.UserConfirmed
                    ? "Registration successful"
                    : "Registration successful. Please check your email for confirmation code.",
                RoleName = userRole.RoleName
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error registering user {Username}", request.Username);
            return Result<RegisterUserResponse>.Failure("An error occurred during registration");
        }
    }
}
