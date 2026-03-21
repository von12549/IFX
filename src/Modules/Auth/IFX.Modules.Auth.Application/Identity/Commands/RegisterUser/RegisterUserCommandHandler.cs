using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.RegisterUser;

public class RegisterUserCommandHandler : IRequestHandler<RegisterUserCommand, Result<RegisterUserResponse>>
{
    private readonly IIdentityProvider _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RegisterUserCommandHandler> _logger;

    public RegisterUserCommandHandler(
        IIdentityProvider identityProvider,
        IUnitOfWork unitOfWork,
        ILogger<RegisterUserCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<RegisterUserResponse>> Handle(
        RegisterUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get primary IdP
            var primaryIdp = await _unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
            if (primaryIdp == null)
            {
                _logger.LogError("Primary IdP not found or not enabled in database");
                return Result<RegisterUserResponse>.Failure("System configuration error. Please contact support.");
            }
            // Check if user already exists
            var existingUser = await _unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, primaryIdp.Id, cancellationToken);
            if (existingUser != null)
            {
                return Result<RegisterUserResponse>.Failure("User with this email already exists");
            }

            // Create user in identity provider
            var cognitoResult = await _identityProvider.SignUpAsync(
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
            var userRole = await _unitOfWork.Roles.GetByNameAsync("User", cancellationToken);
            if (userRole == null)
            {
                _logger.LogError("Default 'User' role not found in database");
                return Result<RegisterUserResponse>.Failure("System configuration error. Please contact support.");
            }

            // Create User entity
            var displayName = $"{request.FirstName} {request.LastName}";
            var user = User.Create(displayName, isActive: false); // Will be activated after confirmation
            user.AddRole(userRole);

            await _unitOfWork.Users.AddAsync(user, cancellationToken);

            // Create UserIdentity entity (all identity data)
            var userIdentity = UserIdentity.Create(
                userId: user.Id,
                idpId: primaryIdp.Id,
                issuer: primaryIdp.Issuer,
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
                    : "Registration successful. Please check your email for confirmation code."
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error registering user {Username}", request.Username);
            return Result<RegisterUserResponse>.Failure("An error occurred during registration");
        }
    }
}
