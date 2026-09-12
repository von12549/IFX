using FluentAssertions;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Moq;

namespace IFX.Modules.IAM.Application.Tests.Handlers.Authorization;

public sealed class CrossTenantAccessGuardTests
{
    [Theory]
    [InlineData(GlobalRoleNames.PlatformAdmin)]
    [InlineData(GlobalRoleNames.PlatformSupport)]
    [InlineData(GlobalRoleNames.PlatformAuditor)]
    public async Task Require_WithApprovedRoleAndPermission_AllowsAccess(string globalRole)
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), [globalRole], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.RequireAsync(currentUser.Object, Permission(currentUser.Object));

        await action.Should().NotThrowAsync();
    }

    [Fact]
    public async Task Require_WithoutPermission_FailsClosed()
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), [GlobalRoleNames.PlatformAdmin], []);

        var action = () => CrossTenantAccessGuard.RequireAsync(currentUser.Object, Permission(currentUser.Object));

        await action.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Require_WithUnknownGlobalRole_FailsClosed()
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), ["UnregisteredPlatformRole"], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.RequireAsync(currentUser.Object, Permission(currentUser.Object));

        await action.Should().ThrowAsync<ForbiddenException>();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Require_WithMissingTrustedActor_FailsClosed(bool authenticated)
    {
        var currentUser = CreateCurrentUser(authenticated, Guid.Empty, [GlobalRoleNames.PlatformAdmin], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.RequireAsync(currentUser.Object, Permission(currentUser.Object));

        await action.Should().ThrowAsync<ForbiddenException>();
    }

    private static IPermissionChecker Permission(ICurrentUser user)
    {
        var permission = new Mock<IPermissionChecker>();
        permission.Setup(p => p.HasPermissionAsync(CrossTenantAccessGuard.RequiredPermission, It.IsAny<CancellationToken>())).ReturnsAsync(user.Permissions.Contains(CrossTenantAccessGuard.RequiredPermission));
        return permission.Object;
    }
    private static Mock<ICurrentUser> CreateCurrentUser(
        bool authenticated,
        Guid userId,
        IReadOnlyList<string> globalRoles,
        IReadOnlyCollection<string> permissions)
    {
        var currentUser = new Mock<ICurrentUser>();
        currentUser.SetupGet(x => x.IsAuthenticated).Returns(authenticated);
        currentUser.SetupGet(x => x.UserId).Returns(userId);
        currentUser.SetupGet(x => x.GlobalRoles).Returns(globalRoles);
        currentUser.SetupGet(x => x.Permissions).Returns(permissions);
        return currentUser;
    }

    [Fact]
    public void RequireTenant_WithTrustedTenant_ReturnsTenant()
    {
        var tenantId = Guid.NewGuid();
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), [], []);
        currentUser.SetupGet(x => x.TenantId).Returns(tenantId);

        TenantAccessGuard.RequireTenant(currentUser.Object).Should().Be(tenantId);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task RequireTenant_WithoutTrustedTenant_FailsClosed(bool authenticated)
    {
        var currentUser = CreateCurrentUser(authenticated, Guid.NewGuid(), [], []);
        currentUser.SetupGet(x => x.TenantId).Returns((Guid?)null);

        Func<Task> action = () => Task.FromResult(TenantAccessGuard.RequireTenant(currentUser.Object));

        await action.Should().ThrowAsync<ForbiddenException>();
    }
}
