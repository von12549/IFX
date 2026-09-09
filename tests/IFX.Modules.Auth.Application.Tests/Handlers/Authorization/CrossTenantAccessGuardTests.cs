using FluentAssertions;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Domain.Authorization;
using Moq;

namespace IFX.Modules.Auth.Application.Tests.Handlers.Authorization;

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
}
