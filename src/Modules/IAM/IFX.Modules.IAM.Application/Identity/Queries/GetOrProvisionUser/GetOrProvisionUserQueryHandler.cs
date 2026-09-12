using IFX.Modules.IAM.Application.Identity.Commands.ProvisionSsoUser;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Queries.GetOrProvisionUser;

public class GetOrProvisionUserQueryHandler : IRequestHandler<GetOrProvisionUserQuery, Result<UserAuthResult>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMediator _mediator;
    private readonly IOidcDiscoveryService _discoveryService;
    private readonly IOidcUserInfoClient _userInfoClient;
    private readonly ILogger<GetOrProvisionUserQueryHandler> _logger;

    public GetOrProvisionUserQueryHandler(
        IUnitOfWork unitOfWork,
        IMediator mediator,
        IOidcDiscoveryService discoveryService,
        IOidcUserInfoClient userInfoClient,
        ILogger<GetOrProvisionUserQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mediator = mediator;
        _discoveryService = discoveryService;
        _userInfoClient = userInfoClient;
        _logger = logger;
    }

    public async Task<Result<UserAuthResult>> Handle(
        GetOrProvisionUserQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            // 1. Try to find existing user by issuer/subject (with permissions eager-loaded)
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(
                request.Issuer, request.Subject, cancellationToken);

            if (user != null)
            {
                var allRoles = user.Roles
                    .Concat(user.RoleGroups.SelectMany(g => g.Roles))
                    .ToList();

                var permissions = allRoles
                    .SelectMany(r => r.Permissions)
                    .Select(p => p.Name)
                    .Distinct()
                    .ToList();

                var roleNames = allRoles.Select(r => r.Name).Distinct().ToList();
                var departmentNames = user.Departments.Select(d => d.Name).Distinct().ToList();

                _logger.LogDebug(
                    "Found existing user {UserId} with {PermissionCount} permissions for {Issuer}/{Subject}",
                    user.Id, permissions.Count, request.Issuer, request.Subject);

                return Result<UserAuthResult>.Success(new UserAuthResult
                {
                    UserId = user.Id,
                    PrimaryTenantId = user.PrimaryTenantId,
                    TenantIds = user.Tenants.Select(t => t.Id).ToList(),
                    PermissionNames = permissions,
                    RoleNames = roleNames,
                    DepartmentNames = departmentNames,
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

            // 4. Fetch user info from OIDC userinfo endpoint
            string? email = null;
            string? firstName = null;
            string? lastName = null;
            bool emailVerified = false;

            try
            {
                var discoveryDoc = await _discoveryService.GetDiscoveryDocumentAsync(request.Issuer, cancellationToken);

                if (!string.IsNullOrEmpty(discoveryDoc.UserInfoEndpoint))
                {
                    var userInfo = await _userInfoClient.GetAsync(
                        discoveryDoc.UserInfoEndpoint,
                        request.AccessToken,
                        cancellationToken);

                    if (userInfo is not null)
                    {
                        email = userInfo.Email;
                        firstName = userInfo.GivenName;
                        lastName = userInfo.FamilyName;
                        emailVerified = userInfo.EmailVerified;

                        _logger.LogInformation(
                            "Retrieved user info for {Subject}: email={Email}",
                            request.Subject,
                            email);
                    }
                }
                else
                {
                    _logger.LogWarning(
                        "No userinfo endpoint available for issuer {Issuer}",
                        request.Issuer);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to fetch user info from OIDC endpoint for {Issuer}/{Subject}",
                    request.Issuer, request.Subject);
            }

            // 5. Use fallback if userinfo failed
            if (string.IsNullOrEmpty(email))
            {
                _logger.LogWarning(
                    "Using placeholder email for {Issuer}/{Subject} - userinfo unavailable",
                    request.Issuer, request.Subject);
                email = $"{request.Subject}@pending.local";
                emailVerified = false;
            }

            // 6. Auto-provision via existing command
            var provisionCommand = new ProvisionSsoUserCommand(
                IdpId: request.IdpId.Value,
                Issuer: request.Issuer,
                Subject: request.Subject,
                IdpType: request.IdpType.Value,
                Email: email,
                FirstName: firstName,
                LastName: lastName,
                EmailVerified: emailVerified,
                IpAddress: request.IpAddress);

            var provisionResult = await _mediator.Send(provisionCommand, cancellationToken);

            if (!provisionResult.IsSuccess)
            {
                // Concurrent request may have created the user between our "not found" check and
                // the failed save (TOCTOU race condition). Re-read before declaring failure.
                var concurrentUser = await _unitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(
                    request.Issuer, request.Subject, cancellationToken);

                if (concurrentUser != null)
                {
                    _logger.LogInformation(
                        "SSO provisioning race condition resolved for {Issuer}/{Subject} — returning user created by concurrent request",
                        request.Issuer, request.Subject);

                    var concurrentAllRoles = concurrentUser.Roles
                        .Concat(concurrentUser.RoleGroups.SelectMany(g => g.Roles))
                        .ToList();

                    return Result<UserAuthResult>.Success(new UserAuthResult
                    {
                        UserId = concurrentUser.Id,
                        PrimaryTenantId = concurrentUser.PrimaryTenantId,
                        TenantIds = concurrentUser.Tenants.Select(t => t.Id).ToList(),
                        PermissionNames = concurrentAllRoles.SelectMany(r => r.Permissions).Select(p => p.Name).Distinct().ToList(),
                        RoleNames = concurrentAllRoles.Select(r => r.Name).Distinct().ToList(),
                        DepartmentNames = concurrentUser.Departments.Select(d => d.Name).Distinct().ToList(),
                        WasProvisioned = false
                    });
                }

                _logger.LogWarning("SSO user provisioning failed: {Error}", provisionResult.Error);
                return Result<UserAuthResult>.Failure(provisionResult.Error!);
            }

            _logger.LogInformation(
                "Auto-provisioned SSO user {UserId} with {PermissionCount} permissions for {Issuer}/{Subject}",
                provisionResult.Value!.UserId,
                provisionResult.Value.PermissionNames.Count,
                request.Issuer,
                request.Subject);

            return Result<UserAuthResult>.Success(new UserAuthResult
            {
                UserId = provisionResult.Value.UserId,
                PermissionNames = provisionResult.Value.PermissionNames,
                RoleNames = provisionResult.Value.RoleNames,
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
