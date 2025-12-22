using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.ConfirmRegistration;

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
            // Get user by email
            var user = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
            if (user == null)
            {
                return Result<ConfirmRegistrationResponse>.Failure("User not found");
            }

            // Confirm in Cognito
            var confirmed = await _cognitoService.ConfirmSignUpAsync(user.Username, request.ConfirmationCode);
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
