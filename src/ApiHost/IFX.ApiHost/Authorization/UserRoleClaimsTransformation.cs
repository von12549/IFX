using System.Security.Claims;
using IFX.ApiHost.Authentication;
using IFX.Modules.Auth.Application.Queries.GetOrProvisionUser;
using MediatR;
using Microsoft.AspNetCore.Authentication;

namespace IFX.ApiHost.Authorization;

/// <summary>
/// Claims transformation that adds role claims to authenticated principals.
/// Delegates user lookup and auto-provisioning to the Application layer via CQRS.
/// </summary>
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

        // 2. Extract subject and issuer from JWT claims
        var subject = principal.FindFirst("sub")?.Value;
        var issuer = principal.FindFirst("iss")?.Value;

        if (string.IsNullOrEmpty(subject) || string.IsNullOrEmpty(issuer))
        {
            _logger.LogWarning("Missing sub or iss claim in JWT");
            return principal;
        }

        try
        {
            // 3. Get IdP configuration from HttpContext (set by DynamicJwtBearerEvents)
            var httpContext = _httpContextAccessor.HttpContext;
            var idpConfig = httpContext?.Items["IdpConfiguration"]
                as IdpConfigurationEntry;

            // 4. Get access token from HttpContext (set by DynamicJwtBearerEvents)
            var accessToken = httpContext?.Items["AccessToken"]?.ToString()
                ?? string.Empty;

            // 5. Build query with access token for userinfo fetch
            var query = new GetOrProvisionUserQuery(
                Issuer: issuer,
                Subject: subject,
                AccessToken: accessToken,
                AutoProvisionEnabled: idpConfig?.AutoProvisionEnabled ?? false,
                IdpId: idpConfig?.IdpId,
                IdpType: idpConfig?.IdpType,
                IpAddress: httpContext?.Connection.RemoteIpAddress?.ToString());

            // 6. Execute query via MediatR (create scope for scoped services)
            using var scope = _serviceProvider.CreateScope();
            var mediator = scope.ServiceProvider.GetRequiredService<IMediator>();
            var result = await mediator.Send(query);

            if (!result.IsSuccess)
            {
                _logger.LogWarning(
                    "User authentication failed for {Issuer}/{Subject}: {Error}",
                    issuer, subject, result.Error);
                return new ClaimsPrincipal(); // Return empty principal to trigger 401
            }

            // 7. Add role and user_id claims from query result
            var identity = new ClaimsIdentity();
            identity.AddClaim(new Claim(ClaimTypes.Role, result.Value!.RoleName));
            identity.AddClaim(new Claim("user_id", result.Value.UserId.ToString()));
            principal.AddIdentity(identity);

            return principal;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error transforming claims for user {Issuer}/{Subject}", issuer, subject);
            return principal;
        }
    }
}
