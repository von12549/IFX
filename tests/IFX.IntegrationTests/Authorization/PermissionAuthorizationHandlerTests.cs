using IFX.ApiHost.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using Moq;
namespace IFX.IntegrationTests.Authorization;
public sealed class PermissionAuthorizationHandlerTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Handler_uses_current_IAM_decision_even_when_claims_disagree(bool allowed)
    {
        var permission = new Mock<IPermissionChecker>(MockBehavior.Strict);
        permission.Setup(p => p.HasPermissionAsync("User:update", default)).ReturnsAsync(allowed);
        var requirement = new PermissionRequirement("User:update");
        var claims = allowed ? Array.Empty<Claim>() : new[] { new Claim("permission", "User:update"), new Claim("global_role", "PlatformAdmin") };
        var context = new AuthorizationHandlerContext([requirement], new ClaimsPrincipal(new ClaimsIdentity(claims, "test")), null);
        await new PermissionAuthorizationHandler(permission.Object).HandleAsync(context);
        Assert.Equal(allowed, context.HasSucceeded);
        permission.Verify(p => p.HasPermissionAsync("User:update", default), Times.Once);
    }
}
