using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using Microsoft.AspNetCore.Authorization;

namespace IFX.ApiHost.Authorization;

/// <summary>
/// Checks whether the authenticated user holds the required permission claim.
/// Permission claims are injected by UserPermissionClaimsTransformation on every
/// authenticated request — no additional database call is needed here.
/// Users with any GlobalRole bypass the permission gate — fine-grained access is
/// controlled by the ABAC layer (OPA) via GlobalRoleIncludes condition templates.
/// </summary>
public class PermissionAuthorizationHandler : AuthorizationHandler<PermissionRequirement>
{
    private readonly ICurrentUser _currentUser;

    public PermissionAuthorizationHandler(ICurrentUser currentUser)
    {
        _currentUser = currentUser;
    }

    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        PermissionRequirement requirement)
    {
        if (_currentUser.GlobalRoles.Count > 0 ||
            context.User.HasClaim("permission", requirement.PermissionName))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
