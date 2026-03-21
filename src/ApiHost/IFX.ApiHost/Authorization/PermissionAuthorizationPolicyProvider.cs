using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace IFX.ApiHost.Authorization;

/// <summary>
/// Dynamically creates an authorization policy for any permission name (e.g. "User.Read").
/// Falls back to the default policy provider for built-in policies.
/// </summary>
public class PermissionAuthorizationPolicyProvider : DefaultAuthorizationPolicyProvider
{
    public PermissionAuthorizationPolicyProvider(IOptions<AuthorizationOptions> options)
        : base(options) { }

    public override async Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        var existingPolicy = await base.GetPolicyAsync(policyName);
        if (existingPolicy is not null)
            return existingPolicy;

        // Treat any unknown policy name as a permission name
        return new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .AddRequirements(new PermissionRequirement(policyName))
            .Build();
    }
}
