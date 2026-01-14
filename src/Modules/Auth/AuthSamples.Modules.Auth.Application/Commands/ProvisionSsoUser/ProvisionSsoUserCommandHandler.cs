using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.Enums;
using AuthSamples.Modules.Auth.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.ProvisionSsoUser;

public class ProvisionSsoUserCommandHandler : IRequestHandler<ProvisionSsoUserCommand, Result<ProvisionSsoUserResponse>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ProvisionSsoUserCommandHandler> _logger;

    public ProvisionSsoUserCommandHandler(
        IUnitOfWork unitOfWork,
        ILogger<ProvisionSsoUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<ProvisionSsoUserResponse>> Handle(
        ProvisionSsoUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Check if user already exists by issuer/subject
            var existingUser = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(
                request.Issuer, request.Subject, cancellationToken);

            if (existingUser != null)
            {
                var existingRole = await _unitOfWork.UserRoles.GetByIdAsync(
                    existingUser.UserRoleId, cancellationToken);

                return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse
                {
                    UserId = existingUser.Id,
                    RoleName = existingRole?.RoleName ?? "Unknown",
                    WasProvisioned = false
                });
            }

            // Determine role based on IdP type:
            // - Internal IdP → "User" role
            // - External IdP → "SsoUser" role
            var roleName = request.IdpType == IdpType.Internal ? "User" : "SsoUser";
            var userRole = await _unitOfWork.UserRoles.GetByRoleNameAsync(roleName, cancellationToken);
            if (userRole == null)
            {
                _logger.LogError("'{RoleName}' role not found in database", roleName);
                return Result<ProvisionSsoUserResponse>.Failure(
                    "System configuration error. Please contact support.");
            }

            // Create display name
            var displayName = !string.IsNullOrEmpty(request.FirstName) || !string.IsNullOrEmpty(request.LastName)
                ? $"{request.FirstName} {request.LastName}".Trim()
                : request.Email!;

            // Create User entity
            var user = User.Create(
                userRoleId: userRole.Id,
                displayName: displayName,
                isActive: true); // SSO users are active immediately

            await _unitOfWork.Users.AddAsync(user, cancellationToken);

            // Create UserIdentity entity
            var userIdentity = UserIdentity.Create(
                userId: user.Id,
                idpId: request.IdpId,
                issuer: request.Issuer,
                subject: Subject.Create(request.Subject),
                email: EmailAddress.Create(request.Email!),
                firstName: request.FirstName ?? string.Empty,
                lastName: request.LastName ?? string.Empty,
                birthDate: string.Empty,
                phoneNumber: string.Empty,
                emailVerified: request.EmailVerified,
                phoneNumberVerified: false);

            await _unitOfWork.UserIdentities.AddAsync(userIdentity, cancellationToken);

            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Registration,
                $"User auto-provisioned via SSO from {request.Issuer} (IdpType: {request.IdpType})",
                request.IpAddress ?? "Unknown");

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Auto-provisioned SSO user {UserId} from {Issuer} with subject {Subject}, assigned role {RoleName}",
                user.Id, request.Issuer, request.Subject, userRole.RoleName);

            return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse
            {
                UserId = user.Id,
                RoleName = userRole.RoleName,
                WasProvisioned = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error provisioning SSO user from {Issuer}", request.Issuer);
            return Result<ProvisionSsoUserResponse>.Failure("An error occurred during SSO user provisioning");
        }
    }
}
