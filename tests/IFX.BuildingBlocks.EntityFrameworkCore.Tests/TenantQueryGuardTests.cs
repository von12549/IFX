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
}
