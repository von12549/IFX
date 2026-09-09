using FluentAssertions;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Tests;

public sealed class TenantQueryGuardTests
{
    [Fact]
    public void Require_WithNonEmptyTenant_ReturnsTenant()
    {
        var tenantId = Guid.NewGuid();

        IFX.BuildingBlocks.EntityFrameworkCore.TenantQueryGuard.Require(tenantId).Should().Be(tenantId);
    }

    [Fact]
    public void Require_WithEmptyTenant_FailsClosed()
    {
        var action = () => IFX.BuildingBlocks.EntityFrameworkCore.TenantQueryGuard.Require(Guid.Empty);

        action.Should().Throw<ArgumentException>()
            .WithParameterName("tenantId")
            .WithMessage("Tenant-scoped queries require a non-empty tenant identity.*");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(501)]
    public void RequireBoundedLimit_WithUnboundedValue_FailsClosed(int maxRows)
    {
        var action = () => IFX.BuildingBlocks.EntityFrameworkCore.TenantQueryGuard.RequireBoundedLimit(maxRows);

        action.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void RequireBoundedLimit_WithMaximum_ReturnsLimit()
    {
        IFX.BuildingBlocks.EntityFrameworkCore.TenantQueryGuard.RequireBoundedLimit(500).Should().Be(500);
    }
}
