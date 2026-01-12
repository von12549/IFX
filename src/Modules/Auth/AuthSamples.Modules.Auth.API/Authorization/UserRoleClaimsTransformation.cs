using System.Security.Claims;
using AuthSamples.Modules.Auth.Application.Interfaces;
using Microsoft.AspNetCore.Authentication;

namespace AuthSamples.Modules.Auth.API.Authorization;

public class UserRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<UserRoleClaimsTransformation> _logger;

    public UserRoleClaimsTransformation(
        IServiceProvider serviceProvider,
        ILogger<UserRoleClaimsTransformation> logger)
    {
        _serviceProvider = serviceProvider;
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
            // 3. Create scope to resolve scoped services (IUnitOfWork)
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            // 4. Load user with role from database using Issuer + Subject
            var user = await unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);
            if (user?.UserRole == null)
            {
                _logger.LogWarning("User with Issuer {Issuer} and Subject {Subject} not found or has no role assigned", issuer, subject);
                return principal;
            }

            // 5. Clone identity and add role claim
            var claimsIdentity = new ClaimsIdentity();
            claimsIdentity.AddClaim(new Claim(ClaimTypes.Role, user.UserRole.RoleName));

            // 6. Add to principal
            principal.AddIdentity(claimsIdentity);

            _logger.LogDebug(
                "Added role claim '{RoleName}' for user {Issuer}/{Subject}",
                user.UserRole.RoleName,
                issuer,
                subject);

            return principal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error transforming claims for user {Issuer}/{Subject}", issuer, subject);
            return principal;
        }
    }
}
