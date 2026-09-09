using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.ProvisionSsoUser;
public class ProvisionSsoUserCommandHandler : IRequestHandler<ProvisionSsoUserCommand, Result<ProvisionSsoUserResponse>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ProvisionSsoUserCommandHandler> _logger;
    public ProvisionSsoUserCommandHandler(IUnitOfWork unitOfWork, ILogger<ProvisionSsoUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<ProvisionSsoUserResponse>> Handle(ProvisionSsoUserCommand request, CancellationToken cancellationToken)
    {
        {
            // Check if user already exists by issuer/subject
            var existingUser = await _unitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(request.Issuer, request.Subject, cancellationToken);
            if (existingUser != null)
            {
                var existingIdentity = existingUser.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);
                var existingPermissions = existingUser.Roles.Concat(existingUser.RoleGroups.SelectMany(g => g.Roles)).SelectMany(r => r.Permissions).Select(p => p.Name).Distinct().ToList();
                return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse { UserId = existingUser.Id, UserIdentityId = existingIdentity?.Id ?? Guid.Empty, PermissionNames = existingPermissions, WasProvisioned = false, RequiresEmailVerification = existingIdentity != null && !existingIdentity.EmailVerified, Email = existingIdentity?.Email?.Value });
            }

            // Always assign "PendingUser" role for auto-provisioned users
            const string roleName = "PendingUser";
            var idp = await _unitOfWork.Idps.GetEnabledByIssuerAsync(request.Issuer, cancellationToken);
            if (idp is null || idp.Id != request.IdpId)
            {
                return Result<ProvisionSsoUserResponse>.Failure("Identity provider is not enabled or does not match the trusted issuer.");
            }
            var userRole = await _unitOfWork.Roles.GetByNameAsync(roleName, idp.TenantId, cancellationToken);
            if (userRole == null)
            {
                _logger.LogError("'{RoleName}' role not found in database", roleName);
                return Result<ProvisionSsoUserResponse>.Failure("System configuration error. Please contact support.");
            }

            // Create display name
            var displayName = !string.IsNullOrEmpty(request.FirstName) || !string.IsNullOrEmpty(request.LastName) ? $"{request.FirstName} {request.LastName}".Trim() : request.Email!;
            // Create User entity
            var user = User.Create(displayName, isActive: true); // SSO users are active immediately
            user.AddRole(userRole);
            user.CreatedBy = user.Id; // self-provisioned
            await _unitOfWork.Users.AddAsync(user, cancellationToken);
            // Create UserIdentity entity
            var userIdentity = UserIdentity.Create(userId: user.Id, idpId: request.IdpId, issuer: request.Issuer, subject: Subject.Create(request.Subject), email: EmailAddress.Create(request.Email!), firstName: request.FirstName ?? string.Empty, lastName: request.LastName ?? string.Empty, birthDate: string.Empty, phoneNumber: string.Empty, emailVerified: request.EmailVerified, phoneNumberVerified: false);
            userIdentity.CreatedBy = user.Id;
            await _unitOfWork.UserIdentities.AddAsync(userIdentity, cancellationToken);
            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(user.Id, ActivityType.Registration, $"User auto-provisioned via SSO from {request.Issuer} (IdpType: {request.IdpType}) - Pending profile completion", request.IpAddress ?? "Unknown");
            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);
            // Check if email verification is needed
            var requiresEmailVerification = !request.EmailVerified && !string.IsNullOrEmpty(request.Email);
            _logger.LogInformation("Auto-provisioned SSO user {UserId} from {Issuer} with subject {Subject}, assigned role {RoleName}, RequiresEmailVerification: {RequiresVerification}", user.Id, request.Issuer, request.Subject, userRole.Name, requiresEmailVerification);
            var permissionNames = userRole.Permissions.Select(p => p.Name).ToList();
            return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse { UserId = user.Id, UserIdentityId = userIdentity.Id, PermissionNames = permissionNames, RoleNames = [userRole.Name], WasProvisioned = true, RequiresEmailVerification = requiresEmailVerification, Email = request.Email });
        }
    }
}
