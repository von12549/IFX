using System.Security.Claims;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Auth.Infrastructure.Authorization;
using IFX.Platform.Context.Contracts;
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
    public void Tenant_selection_reads_only_the_trusted_execution_scope()
    {
        var selectedTenantId = Guid.NewGuid();
        var context = new ExecutionContextSnapshot(
            CorrelationId.New(),
            OperationId.New(),
            causationId: null,
            ExecutionScope.ForTenant(new TenantScope(selectedTenantId)),
            new ActorReference(ActorKind.User, Guid.NewGuid().ToString("D")),
            new SourceReference("ifx", "test", 1));
        var accessor = new Mock<IExecutionContextAccessor>();
        accessor.SetupGet(candidate => candidate.HasCurrent).Returns(true);
        accessor.SetupGet(candidate => candidate.Current).Returns(context);
        var selection = new ExecutionTenantSelection(accessor.Object);

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
