using Microsoft.AspNetCore.Authorization;

namespace IFX.ApiHost.Authorization;

/// <summary>
/// Checks whether the authenticated user holds the required permission claim.
/// Permission claims are injected by UserPermissionClaimsTransformation on every
/// authenticated request — no additional database call is needed here.
/// </summary>
public class PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        PermissionRequirement requirement)
    {
        if (context.User.HasClaim("permission", requirement.PermissionName))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
