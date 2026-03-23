using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using Microsoft.AspNetCore.Http;

namespace IFX.Modules.Auth.Infrastructure.Authorization;

/// <summary>
/// Reads the current user's identity and permissions from the ClaimsPrincipal.
/// Permission and user_id claims are injected per-request by UserPermissionClaimsTransformation.
/// tenant_id is added by the same transformation after provisioning.
/// </summary>
public class CurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUser(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    private System.Security.Claims.ClaimsPrincipal? Principal =>
        _httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated =>
        Principal?.Identity?.IsAuthenticated == true;

    public Guid UserId
    {
        get
        {
            var value = Principal?.FindFirst("user_id")?.Value;
            return Guid.TryParse(value, out var id) ? id : Guid.Empty;
        }
    }

    public Guid? TenantId
    {
        get
        {
            var value = Principal?.FindFirst("tenant_id")?.Value;
            return Guid.TryParse(value, out var id) ? id : null;
        }
    }

    public IReadOnlyCollection<string> Departments =>
        Principal?.FindAll("department").Select(c => c.Value).ToList() ?? [];

    public IReadOnlyCollection<string> Roles =>
        Principal?.FindAll(System.Security.Claims.ClaimTypes.Role)
            .Concat(Principal.FindAll("role"))
            .Select(c => c.Value)
            .Distinct()
            .ToList() ?? [];

    public IReadOnlyCollection<string> Permissions =>
        Principal?.FindAll("permission").Select(c => c.Value).ToList() ?? [];

    public bool MfaEnabled
    {
        get
        {
            // Check AMR (Authentication Methods References) claim for MFA indicators
            var amr = Principal?.FindAll("amr").Select(c => c.Value).ToList() ?? [];
            return amr.Contains("mfa") || amr.Contains("otp") || amr.Contains("hwk");
        }
    }
}
