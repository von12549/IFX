using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.ConfirmRegistration;

public class ConfirmRegistrationCommandHandler : IRequestHandler<ConfirmRegistrationCommand, Result<ConfirmRegistrationResponse>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ConfirmRegistrationCommandHandler> _logger;

    public ConfirmRegistrationCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        ILogger<ConfirmRegistrationCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<ConfirmRegistrationResponse>> Handle(
        ConfirmRegistrationCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get primary IdP
            var primaryIdp = await _unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
            if (primaryIdp == null)
            {
                _logger.LogError("Primary IdP not found or not enabled in database");
                return Result<ConfirmRegistrationResponse>.Failure("System configuration error. Please contact support.");
            }
            // Get user by email
            var user = await _unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, primaryIdp.Id, cancellationToken);
            if (user == null)
            {
                return Result<ConfirmRegistrationResponse>.Failure("User not found");
            }

            // Confirm in Cognito (use email as username since Cognito User Pool is configured with email sign-in)
            var confirmed = await _cognitoService.ConfirmSignUpAsync(request.Email, request.ConfirmationCode);
            if (!confirmed)
            {
                return Result<ConfirmRegistrationResponse>.Failure("Invalid confirmation code");
            }

            // Activate user
            user.Activate();
            await _unitOfWork.Users.UpdateAsync(user, cancellationToken);

            // Update RegistrationFlowEvent
            var registrationEvent = await _unitOfWork.RegistrationFlowEvents
                .GetByEmailAsync(request.Email, cancellationToken);

            if (registrationEvent != null)
            {
                registrationEvent.Confirm(user.Id);
                await _unitOfWork.RegistrationFlowEvents.UpdateAsync(registrationEvent, cancellationToken);
            }

            // Create UserActivityLog
            var activityLog = Domain.Entities.UserActivityLog.Create(
                user.Id,
                ActivityType.RegistrationConfirmed,
                "User registration confirmed",
                request.IpAddress);

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("User {Email} confirmed registration successfully", request.Email);

            return Result<ConfirmRegistrationResponse>.Success(new ConfirmRegistrationResponse
            {
                Success = true,
                Message = "Registration confirmed successfully"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error confirming registration for {Email}", request.Email);
            return Result<ConfirmRegistrationResponse>.Failure("An error occurred during confirmation");
        }
    }
}
