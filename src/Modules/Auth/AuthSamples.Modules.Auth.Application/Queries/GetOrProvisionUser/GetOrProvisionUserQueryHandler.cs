using AuthSamples.Modules.Auth.Application.Commands.ProvisionSsoUser;
using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Queries.GetOrProvisionUser;

public class GetOrProvisionUserQueryHandler : IRequestHandler<GetOrProvisionUserQuery, Result<UserAuthResult>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMediator _mediator;
    private readonly ILogger<GetOrProvisionUserQueryHandler> _logger;

    public GetOrProvisionUserQueryHandler(
        IUnitOfWork unitOfWork,
        IMediator mediator,
        ILogger<GetOrProvisionUserQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mediator = mediator;
        _logger = logger;
    }

    public async Task<Result<UserAuthResult>> Handle(
        GetOrProvisionUserQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            // 1. Try to find existing user by issuer/subject
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(
                request.Issuer, request.Subject, cancellationToken);

            if (user != null)
            {
                // User exists - return their info
                if (user.UserRole == null)
                {
                    _logger.LogWarning(
                        "User {Issuer}/{Subject} has no role assigned",
                        request.Issuer, request.Subject);
                    return Result<UserAuthResult>.Failure("User has no role assigned");
                }

                _logger.LogDebug(
                    "Found existing user {UserId} with role '{RoleName}' for {Issuer}/{Subject}",
                    user.Id, user.UserRole.RoleName, request.Issuer, request.Subject);

                return Result<UserAuthResult>.Success(new UserAuthResult
                {
                    UserId = user.Id,
                    RoleName = user.UserRole.RoleName,
                    WasProvisioned = false
                });
            }

            // 2. User not found - check if auto-provisioning is enabled
            if (!request.AutoProvisionEnabled)
            {
                _logger.LogWarning(
                    "User with Issuer {Issuer} and Subject {Subject} not found and auto-provision disabled",
                    request.Issuer, request.Subject);
                return Result<UserAuthResult>.Failure("User not found");
            }

            // 3. Validate required fields for provisioning
            if (!request.IdpId.HasValue || !request.IdpType.HasValue)
            {
                _logger.LogWarning(
                    "Cannot provision user: IdpId and IdpType are required");
                return Result<UserAuthResult>.Failure("IdP configuration missing for auto-provisioning");
            }

            if (string.IsNullOrEmpty(request.Email))
            {
                _logger.LogWarning(
                    "SSO user from {Issuer}/{Subject} rejected: missing email",
                    request.Issuer, request.Subject);
                return Result<UserAuthResult>.Failure("Email is required for auto-provisioning");
            }

            // 4. Auto-provision via existing command
            var provisionCommand = new ProvisionSsoUserCommand(
                IdpId: request.IdpId.Value,
                Issuer: request.Issuer,
                Subject: request.Subject,
                IdpType: request.IdpType.Value,
                Email: request.Email,
                FirstName: request.FirstName,
                LastName: request.LastName,
                EmailVerified: request.EmailVerified,
                IpAddress: request.IpAddress);

            var provisionResult = await _mediator.Send(provisionCommand, cancellationToken);

            if (!provisionResult.IsSuccess)
            {
                _logger.LogWarning("SSO user provisioning failed: {Error}", provisionResult.Error);
                return Result<UserAuthResult>.Failure(provisionResult.Error!);
            }

            _logger.LogInformation(
                "Auto-provisioned SSO user {UserId} with role '{RoleName}' for {Issuer}/{Subject}",
                provisionResult.Value!.UserId,
                provisionResult.Value.RoleName,
                request.Issuer,
                request.Subject);

            return Result<UserAuthResult>.Success(new UserAuthResult
            {
                UserId = provisionResult.Value.UserId,
                RoleName = provisionResult.Value.RoleName,
                WasProvisioned = provisionResult.Value.WasProvisioned
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error getting or provisioning user for {Issuer}/{Subject}",
                request.Issuer, request.Subject);
            return Result<UserAuthResult>.Failure("An error occurred during user authentication");
        }
    }
}
