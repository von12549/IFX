using System.Security.Claims;
using IFX.Modules.Auth.Infrastructure.Authorization;
using Microsoft.AspNetCore.Http;

namespace IFX.Modules.Auth.Infrastructure.Tests.Authorization;

public sealed class HttpContextFactTests
{
    [Fact]
    public void Identity_facts_are_read_without_tenant_selection_policy()
    {
        var userId = Guid.NewGuid();
        var tenantId = Guid.NewGuid();
        var accessor = CreateAccessor(
            new Claim("user_id", userId.ToString("D")),
            new Claim("tenant_id", tenantId.ToString("D")),
            new Claim("tenant", tenantId.ToString("D")),
            new Claim(ClaimTypes.Role, "analyst"),
            new Claim("permission", "holdings.read"),
            new Claim("amr", "mfa"));

        var facts = new HttpIdentityFacts(accessor);

        facts.IsAuthenticated.Should().BeTrue();
        facts.UserId.Should().Be(userId);
        facts.PrimaryTenantId.Should().Be(tenantId);
        facts.IsTenantMember(tenantId).Should().BeTrue();
        facts.Roles.Should().ContainSingle("analyst");
        facts.Permissions.Should().ContainSingle("holdings.read");
        facts.MfaEnabled.Should().BeTrue();
    }

    [Fact]
    public void Tenant_selection_accepts_an_explicit_member_tenant()
    {
        var primaryTenantId = Guid.NewGuid();
        var selectedTenantId = Guid.NewGuid();
        var accessor = CreateAccessor(
            new Claim("tenant_id", primaryTenantId.ToString("D")),
            new Claim("tenant", selectedTenantId.ToString("D")));
        accessor.HttpContext!.Request.Headers["X-Tenant-Id"] = selectedTenantId.ToString("D");
        var facts = new HttpIdentityFacts(accessor);
        var selection = new HttpTenantSelection(accessor, facts);

        selection.ResolveTenantId().Should().Be(selectedTenantId);
    }

    private static HttpContextAccessor CreateAccessor(params Claim[] claims) => new()
    {
        HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test"))
        }
    };
}
