using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AuthSamples.Modules.Cognito.Domain.Enums;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.RegisterUser;

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
            // Check if user already exists
            var existingUser = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
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
                request.PhoneNumber);

            if (!cognitoResult.Success)
            {
                return Result<RegisterUserResponse>.Failure(
                    cognitoResult.ErrorMessage ?? "Failed to create user in Cognito");
            }

            // Create User entity
            var user = User.Create(
                CognitoUserId.Create(cognitoResult.CognitoUserId!),
                EmailAddress.Create(request.Email),
                request.Username,
                request.FirstName,
                request.LastName,
                request.PhoneNumber);

            await _unitOfWork.Users.AddAsync(user, cancellationToken);

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
                "User {Username} registered successfully with Cognito ID {CognitoUserId}",
                request.Username,
                cognitoResult.CognitoUserId);

            return Result<RegisterUserResponse>.Success(new RegisterUserResponse
            {
                UserId = user.Id,
                CognitoUserId = cognitoResult.CognitoUserId!,
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
