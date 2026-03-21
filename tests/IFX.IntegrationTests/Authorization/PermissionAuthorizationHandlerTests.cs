using IFX.ApiHost.Authorization;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace IFX.IntegrationTests.Authorization;

public class PermissionAuthorizationHandlerTests
{
    private readonly PermissionAuthorizationHandler _handler = new();

    private static AuthorizationHandlerContext CreateContext(
        PermissionRequirement requirement,
        IEnumerable<Claim>? claims = null)
    {
        var identity = new ClaimsIdentity(claims ?? [], "Test");
        var user = new ClaimsPrincipal(identity);
        return new AuthorizationHandlerContext([requirement], user, null);
    }

    [Fact]
    public async Task HandleAsync_WhenUserHasMatchingPermissionClaim_Succeeds()
    {
        var requirement = new PermissionRequirement("Role.Read");
        var context = CreateContext(requirement, [new Claim("permission", "Role.Read")]);

        await _handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserHasMultiplePermissions_SucceedsForMatchingOne()
    {
        var requirement = new PermissionRequirement("User.Write");
        var context = CreateContext(requirement,
        [
            new Claim("permission", "Role.Read"),
            new Claim("permission", "User.Write"),
        ]);

        await _handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserMissingPermissionClaim_DoesNotSucceed()
    {
        var requirement = new PermissionRequirement("Role.Read");
        var context = CreateContext(requirement, [new Claim("permission", "User.Read")]);

        await _handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleAsync_WhenUserHasNoClaims_DoesNotSucceed()
    {
        var requirement = new PermissionRequirement("Role.Read");
        var context = CreateContext(requirement, []);

        await _handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleAsync_WhenUserIsUnauthenticated_DoesNotSucceed()
    {
        var requirement = new PermissionRequirement("Role.Read");
        var user = new ClaimsPrincipal(new ClaimsIdentity()); // no auth type = unauthenticated
        var context = new AuthorizationHandlerContext([requirement], user, null);

        await _handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }
}
