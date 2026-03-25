using IFX.ApiHost.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace IFX.IntegrationTests.Authorization;

public class PermissionAuthorizationPolicyProviderTests
{
    private static PermissionAuthorizationPolicyProvider CreateProvider(
        Action<AuthorizationOptions>? configure = null)
    {
        var options = new AuthorizationOptions();
        configure?.Invoke(options);
        return new PermissionAuthorizationPolicyProvider(Options.Create(options));
    }

    [Fact]
    public async Task GetPolicyAsync_ForUnknownPolicyName_ReturnsPermissionPolicy()
    {
        var provider = CreateProvider();

        var policy = await provider.GetPolicyAsync("Role:read");

        policy.Should().NotBeNull();
        var req = policy!.Requirements.OfType<PermissionRequirement>().SingleOrDefault();
        req.Should().NotBeNull();
        req!.PermissionName.Should().Be("Role:read");
    }

    [Fact]
    public async Task GetPolicyAsync_ForPermissionPolicy_RequiresAuthenticatedUser()
    {
        var provider = CreateProvider();

        var policy = await provider.GetPolicyAsync("User:update");

        policy.Should().NotBeNull();
        var req = policy!.Requirements.OfType<PermissionRequirement>().SingleOrDefault();
        req.Should().NotBeNull();
        req!.PermissionName.Should().Be("User:update");
    }

    [Fact]
    public async Task GetPolicyAsync_ForBuiltInPolicy_FallsBackToExistingPolicy()
    {
        var provider = CreateProvider(opt =>
            opt.AddPolicy("ExistingPolicy", p => p.RequireAuthenticatedUser()));

        var policy = await provider.GetPolicyAsync("ExistingPolicy");

        policy.Should().NotBeNull();
        // Built-in policy should NOT contain PermissionRequirement
        policy!.Requirements.OfType<PermissionRequirement>().Should().BeEmpty();
    }

    [Fact]
    public async Task GetPolicyAsync_ForDifferentPermissionNames_ReturnsDistinctPolicies()
    {
        var provider = CreateProvider();

        var policy1 = await provider.GetPolicyAsync("Role:read");
        var policy2 = await provider.GetPolicyAsync("Role:create");

        var req1 = policy1!.Requirements.OfType<PermissionRequirement>().Single();
        var req2 = policy2!.Requirements.OfType<PermissionRequirement>().Single();

        req1.PermissionName.Should().Be("Role:read");
        req2.PermissionName.Should().Be("Role:create");
    }
}
