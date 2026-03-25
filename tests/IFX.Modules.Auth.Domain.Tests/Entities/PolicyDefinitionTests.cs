using IFX.Modules.Auth.Domain.Authorization;

namespace IFX.Modules.Auth.Domain.Tests.Entities;

public class PolicyDefinitionTests
{
    private const string ValidJson = "[{\"TemplateName\":\"SameTenant\",\"Parameters\":null}]";

    [Fact]
    public void Create_TenantScope_WithTenantId_Succeeds()
    {
        var tenantId = Guid.NewGuid();
        var policy = PolicyDefinition.Create(
            PolicyScope.Tenant, tenantId, "Name", "user", "read", ValidJson, null);

        policy.Scope.Should().Be(PolicyScope.Tenant);
        policy.TenantId.Should().Be(tenantId);
    }

    [Fact]
    public void Create_PlatformScope_WithNullTenantId_Succeeds()
    {
        var policy = PolicyDefinition.Create(
            PolicyScope.Platform, null, "Name", "user", "read", ValidJson, null);

        policy.Scope.Should().Be(PolicyScope.Platform);
        policy.TenantId.Should().BeNull();
    }

    [Fact]
    public void Create_TenantScope_WithNullTenantId_Throws()
    {
        var act = () => PolicyDefinition.Create(
            PolicyScope.Tenant, null, "Name", "user", "read", ValidJson, null);

        act.Should().Throw<ArgumentException>().WithMessage("*TenantId*");
    }
}
