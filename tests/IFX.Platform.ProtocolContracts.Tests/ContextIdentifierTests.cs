using IFX.Platform.Context.Contracts;

namespace IFX.Platform.ProtocolContracts.Tests;

public sealed class ContextIdentifierTests
{
    [Fact]
    public void CorrelationId_WithEmptyValue_Throws()
    {
        var act = () => new CorrelationId(Guid.Empty);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Identifiers_CanonicalText_RoundTrips()
    {
        var value = Guid.Parse("31571f84-f505-4dfe-a36f-006be67d5ab4");

        CorrelationId.Parse(new CorrelationId(value).ToString()).Value.Should().Be(value);
        OperationId.Parse(new OperationId(value).ToString()).Value.Should().Be(value);
        CausationId.Parse(new CausationId(value).ToString()).Value.Should().Be(value);
        RequestId.Parse(new RequestId(value).ToString()).Value.Should().Be(value);
    }

    [Theory]
    [InlineData("")]
    [InlineData("31571f84f5054dfea36f006be67d5ab4")]
    [InlineData("not-an-id")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public void CorrelationId_WithNonCanonicalValue_IsRejected(string value)
    {
        CorrelationId.TryParse(value, out _).Should().BeFalse();
    }

    [Fact]
    public void ExecutionScope_TenantAndPlatform_AreUnambiguous()
    {
        var tenantId = Guid.NewGuid();
        var tenant = ExecutionScope.ForTenant(new TenantScope(tenantId));
        var platform = ExecutionScope.ForPlatform(new PlatformScope());

        tenant.IsTenant.Should().BeTrue();
        tenant.RequireTenant().TenantId.Should().Be(tenantId);
        platform.IsPlatform.Should().BeTrue();
        platform.TenantId.Should().BeNull();
        var act = () => platform.RequireTenant();
        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void TenantScope_WithEmptyTenant_Throws()
    {
        var act = () => new TenantScope(Guid.Empty);

        act.Should().Throw<ArgumentException>();
    }
}
