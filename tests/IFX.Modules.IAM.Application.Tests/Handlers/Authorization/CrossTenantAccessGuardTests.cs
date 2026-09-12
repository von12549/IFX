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
    public void Require_WithApprovedRoleAndPermission_AllowsAccess(string globalRole)
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), [globalRole], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.Require(currentUser.Object);

        action.Should().NotThrow();
    }

    [Fact]
    public void Require_WithoutPermission_FailsClosed()
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), [GlobalRoleNames.PlatformAdmin], []);

        var action = () => CrossTenantAccessGuard.Require(currentUser.Object);

        action.Should().Throw<ForbiddenException>();
    }

    [Fact]
    public void Require_WithUnknownGlobalRole_FailsClosed()
    {
        var currentUser = CreateCurrentUser(true, Guid.NewGuid(), ["UnregisteredPlatformRole"], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.Require(currentUser.Object);

        action.Should().Throw<ForbiddenException>();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Require_WithMissingTrustedActor_FailsClosed(bool authenticated)
    {
        var currentUser = CreateCurrentUser(authenticated, Guid.Empty, [GlobalRoleNames.PlatformAdmin], [CrossTenantAccessGuard.RequiredPermission]);

        var action = () => CrossTenantAccessGuard.Require(currentUser.Object);

        action.Should().Throw<ForbiddenException>();
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
    public void RequireTenant_WithoutTrustedTenant_FailsClosed(bool authenticated)
    {
        var currentUser = CreateCurrentUser(authenticated, Guid.NewGuid(), [], []);
        currentUser.SetupGet(x => x.TenantId).Returns((Guid?)null);

        var action = () => TenantAccessGuard.RequireTenant(currentUser.Object);

        action.Should().Throw<ForbiddenException>();
    }
}
