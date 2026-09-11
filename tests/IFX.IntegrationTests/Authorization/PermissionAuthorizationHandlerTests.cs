using IFX.ApiHost.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace IFX.IntegrationTests.Authorization;

public class PermissionAuthorizationHandlerTests
{
    private sealed class StubCurrentUser(IReadOnlyList<string>? globalRoles = null) : ICurrentUser
    {
        public Guid UserId => Guid.Empty;
        public Guid? TenantId => null;
        public IReadOnlyCollection<string> Departments => [];
        public IReadOnlyCollection<string> Roles => [];
        public IReadOnlyCollection<string> Permissions => [];
        public IReadOnlyList<string> GlobalRoles => globalRoles ?? [];
        public bool IsGlobalAdmin => GlobalRoles.Contains("PlatformAdmin");
        public bool MfaEnabled => false;
        public bool IsAuthenticated => true;
    }

    private static PermissionAuthorizationHandler CreateHandler(params string[] globalRoles)
        => new(new StubCurrentUser(globalRoles.Length > 0 ? globalRoles : null));

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
        var handler = CreateHandler();
        var requirement = new PermissionRequirement("Role:read");
        var context = CreateContext(requirement, [new Claim("permission", "Role:read")]);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserHasMultiplePermissions_SucceedsForMatchingOne()
    {
        var handler = CreateHandler();
        var requirement = new PermissionRequirement("User:update");
        var context = CreateContext(requirement,
        [
            new Claim("permission", "Role:read"),
            new Claim("permission", "User:update"),
        ]);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserMissingPermissionClaim_DoesNotSucceed()
    {
        var handler = CreateHandler();
        var requirement = new PermissionRequirement("Role:read");
        var context = CreateContext(requirement, [new Claim("permission", "User:list")]);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleAsync_WhenUserHasNoClaims_DoesNotSucceed()
    {
        var handler = CreateHandler();
        var requirement = new PermissionRequirement("Role:read");
        var context = CreateContext(requirement, []);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleAsync_WhenUserIsUnauthenticated_DoesNotSucceed()
    {
        var handler = CreateHandler();
        var requirement = new PermissionRequirement("Role:read");
        var user = new ClaimsPrincipal(new ClaimsIdentity()); // no auth type = unauthenticated
        var context = new AuthorizationHandlerContext([requirement], user, null);

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeFalse();
    }

    [Fact]
    public async Task HandleAsync_WhenUserIsGlobalAdmin_SucceedsWithoutPermissionClaim()
    {
        var handler = CreateHandler("PlatformAdmin");
        var requirement = new PermissionRequirement("Platform.Policy:delete");
        var context = CreateContext(requirement, []); // no permission claims at all

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserIsPlatformSupport_SucceedsWithoutPermissionClaim()
    {
        var handler = CreateHandler("PlatformSupport");
        var requirement = new PermissionRequirement("User:read");
        var context = CreateContext(requirement, []); // no permission claims at all

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }

    [Fact]
    public async Task HandleAsync_WhenUserIsPlatformAuditor_SucceedsWithoutPermissionClaim()
    {
        var handler = CreateHandler("PlatformAuditor");
        var requirement = new PermissionRequirement("User:list");
        var context = CreateContext(requirement, []); // no permission claims at all

        await handler.HandleAsync(context);

        context.HasSucceeded.Should().BeTrue();
    }
}
