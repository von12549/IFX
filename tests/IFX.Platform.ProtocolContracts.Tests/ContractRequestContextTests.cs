using IFX.Platform.Context.Contracts.Context;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class ContractRequestContextTests
{
    [Fact]
    public void Constructor_WithTrustedTenantMinimum_CreatesVersionOneContext()
    {
        var causationId = Guid.NewGuid();
        var tenantId = Guid.NewGuid();
        var context = new ContractRequestContext(
            Guid.NewGuid(), Guid.NewGuid(), causationId,
            ContractRequestContext.TenantScope, tenantId,
            "user", Guid.NewGuid().ToString("D"), "ifx", "transaction", 1);

        context.Version.Should().Be(ContractRequestContext.CurrentVersion);
        context.Provenance.Should().Be(ContractRequestContext.TrustedProvenance);
        context.CausationId.Should().Be(causationId);
        context.TenantId.Should().Be(tenantId);
    }

    [Fact]
    public void Constructor_WithPlatformTenant_Throws()
    {
        var act = () => new ContractRequestContext(
            Guid.NewGuid(), Guid.NewGuid(), null,
            ContractRequestContext.PlatformScope, Guid.NewGuid(),
            "system", "scheduler", "ifx", "scheduler", 1);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Constructor_WithUnsupportedVersion_Throws()
    {
        var act = () => new ContractRequestContext(
            Guid.NewGuid(), Guid.NewGuid(), null,
            ContractRequestContext.PlatformScope, null,
            "system", "scheduler", "ifx", "scheduler", 1,
            version: 2);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Theory]
    [InlineData("IFX")]
    [InlineData("ifx_context")]
    [InlineData("")]
    public void Constructor_WithNonCanonicalSourceIdentity_Throws(string value)
    {
        var act = () => new ContractRequestContext(
            Guid.NewGuid(), Guid.NewGuid(), null,
            ContractRequestContext.PlatformScope, null,
            "system", "scheduler", value, "component", 1);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void PublicShape_ContainsOnlyApprovedBclTypes()
    {
        var approved = new[] { typeof(int), typeof(Guid), typeof(Guid?), typeof(string) };

        typeof(ContractRequestContext).GetProperties()
            .Should().OnlyContain(property => approved.Contains(property.PropertyType));
    }
}
