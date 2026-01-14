using System.Security.Claims;
using AuthSamples.ApiHost.Authentication;
using AuthSamples.Modules.Auth.Application.Commands.ProvisionSsoUser;
using AuthSamples.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Authentication;

namespace AuthSamples.ApiHost.Authorization;

public class UserRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<UserRoleClaimsTransformation> _logger;

    public UserRoleClaimsTransformation(
        IServiceProvider serviceProvider,
        IHttpContextAccessor httpContextAccessor,
        ILogger<UserRoleClaimsTransformation> logger)
    {
        _serviceProvider = serviceProvider;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        // 1. Check if already transformed (avoid duplicate transformation)
        if (principal.HasClaim(c => c.Type == ClaimTypes.Role))
        {
            return principal;
        }

        // 2. Get Subject and Issuer from JWT claims
        var subject = principal.FindFirst("sub")?.Value;
        var issuer = principal.FindFirst("iss")?.Value;

        if (string.IsNullOrEmpty(subject) || string.IsNullOrEmpty(issuer))
        {
            _logger.LogWarning("Missing sub or iss claim in JWT");
            return principal;
        }

        try
        {
            // 3. Create scope to resolve scoped services (IUnitOfWork, IMediator)
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            // 4. Try to find existing user
            var user = await unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);

            // 5. If user not found, try auto-provisioning via CQRS command
            if (user == null)
            {
                var idpConfig = _httpContextAccessor.HttpContext?.Items["IdpConfiguration"]
                    as IdpConfigurationEntry;

                if (idpConfig?.AutoProvisionEnabled == true)
                {
                    var email = principal.FindFirst("email")?.Value
                             ?? principal.FindFirst(ClaimTypes.Email)?.Value;

                    if (string.IsNullOrEmpty(email))
                    {
                        _logger.LogWarning(
                            "SSO user from {Issuer}/{Subject} rejected: missing email claim",
                            issuer, subject);
                        return new ClaimsPrincipal(); // Return empty principal to trigger 401
                    }

                    var mediator = scope.ServiceProvider.GetRequiredService<IMediator>();
                    var command = new ProvisionSsoUserCommand(
                        IdpId: idpConfig.IdpId,
                        Issuer: issuer,
                        Subject: subject,
                        IdpType: idpConfig.IdpType,
                        Email: email,
                        FirstName: principal.FindFirst("given_name")?.Value,
                        LastName: principal.FindFirst("family_name")?.Value,
                        EmailVerified: principal.FindFirst("email_verified")?.Value == "true",
                        IpAddress: _httpContextAccessor.HttpContext?.Connection.RemoteIpAddress?.ToString());

                    var result = await mediator.Send(command);

                    if (!result.IsSuccess)
                    {
                        _logger.LogWarning("SSO user provisioning failed: {Error}", result.Error);
                        return new ClaimsPrincipal();
                    }

                    // Add role and user_id claims from provisioning result
                    var claimsIdentity = new ClaimsIdentity();
                    claimsIdentity.AddClaim(new Claim(ClaimTypes.Role, result.Value!.RoleName));
                    claimsIdentity.AddClaim(new Claim("user_id", result.Value.UserId.ToString()));
                    principal.AddIdentity(claimsIdentity);

                    _logger.LogInformation(
                        "Auto-provisioned SSO user {UserId} with role '{RoleName}' for {Issuer}/{Subject}",
                        result.Value.UserId, result.Value.RoleName, issuer, subject);

                    return principal;
                }

                // No auto-provision and user not found
                _logger.LogWarning(
                    "User with Issuer {Issuer} and Subject {Subject} not found and auto-provision disabled",
                    issuer, subject);
                return principal;
            }

            // 6. User exists - add role claim
            if (user.UserRole == null)
            {
                _logger.LogWarning(
                    "User {Issuer}/{Subject} has no role assigned",
                    issuer, subject);
                return principal;
            }

            var identity = new ClaimsIdentity();
            identity.AddClaim(new Claim(ClaimTypes.Role, user.UserRole.RoleName));
            identity.AddClaim(new Claim("user_id", user.Id.ToString()));
            principal.AddIdentity(identity);

            _logger.LogDebug(
                "Added role claim '{RoleName}' for user {Issuer}/{Subject}",
                user.UserRole.RoleName, issuer, subject);

            return principal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error transforming claims for user {Issuer}/{Subject}", issuer, subject);
            return principal;
        }
    }
}
