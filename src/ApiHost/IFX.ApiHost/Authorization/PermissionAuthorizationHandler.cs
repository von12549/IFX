using IFX.BuildingBlocks.Security.Authorization;
using Microsoft.AspNetCore.Authorization;
namespace IFX.ApiHost.Authorization;
// Both HTTP and internal callers use IAM's current, scope-bound permission decision.
public sealed class PermissionAuthorizationHandler(IPermissionChecker permission) : AuthorizationHandler<PermissionRequirement>
{
    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (await permission.HasPermissionAsync(requirement.PermissionName)) context.Succeed(requirement);
    }
}
