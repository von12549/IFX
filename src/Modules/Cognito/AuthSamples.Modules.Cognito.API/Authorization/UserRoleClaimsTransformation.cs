using System.Security.Claims;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using Microsoft.AspNetCore.Authentication;

namespace AuthSamples.Modules.Cognito.API.Authorization;

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

        // 2. Get Subject from "sub" claim
        var subject = principal.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return principal;
        }

        try
        {
            // 3. Create scope to resolve scoped services (IUnitOfWork)
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            // 4. Load user with role from database
            var user = await unitOfWork.Users.GetBySubjectAsync(subject);
            if (user?.UserRole == null)
            {
                _logger.LogWarning("User {Subject} not found or has no role assigned", subject);
                return principal;
            }

            // 5. Clone identity and add role claim
            var claimsIdentity = new ClaimsIdentity();
            claimsIdentity.AddClaim(new Claim(ClaimTypes.Role, user.UserRole.RoleName));

            // 6. Add to principal
            principal.AddIdentity(claimsIdentity);

            _logger.LogDebug(
                "Added role claim '{RoleName}' for user {Subject}",
                user.UserRole.RoleName,
                subject);

            return principal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error transforming claims for user {Subject}", subject);
            return principal;
        }
    }
}
