using IFX.Modules.Holdings.Domain.Entities;
using IFX.Modules.Holdings.Domain.Enums;

namespace IFX.Modules.Holdings.Domain.Tests.Entities;

public class HoldingTests
{
    private static readonly Guid ValidTenantId = Guid.NewGuid();
    private static readonly Guid ValidAccountId = Guid.NewGuid();
    private static readonly Guid ValidClassId = Guid.NewGuid();

    [Fact]
    public void Create_WithValidParameters_ReturnsHolding()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        holding.Should().NotBeNull();
        holding.Id.Should().NotBeEmpty();
        holding.TenantId.Should().Be(ValidTenantId);
        holding.InvestmentAccountId.Should().Be(ValidAccountId);
        holding.ClassId.Should().Be(ValidClassId);
        holding.Units.Should().Be(0m);
        holding.Status.Should().Be(HoldingStatus.Active);
        holding.LastTransactionAt.Should().BeNull();
    }

    [Fact]
    public void Create_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Holding.Create(Guid.Empty, ValidAccountId, ValidClassId);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Fact]
    public void Create_WithEmptyInvestmentAccountId_ThrowsArgumentException()
    {
        var act = () => Holding.Create(ValidTenantId, Guid.Empty, ValidClassId);

        act.Should().Throw<ArgumentException>().WithParameterName("investmentAccountId");
    }

    [Fact]
    public void Create_WithEmptyClassId_ThrowsArgumentException()
    {
        var act = () => Holding.Create(ValidTenantId, ValidAccountId, Guid.Empty);

        act.Should().Throw<ArgumentException>().WithParameterName("classId");
    }

    [Fact]
    public void ApplySubscription_AddsUnitsAndSetsTimestamp()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        var before = DateTime.UtcNow;

        holding.ApplySubscription(100m);

        holding.Units.Should().Be(100m);
        holding.LastTransactionAt.Should().NotBeNull();
        holding.LastTransactionAt.Should().BeOnOrAfter(before);
    }

    [Fact]
    public void ApplySubscription_AccumulatesUnitsOnMultipleCalls()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        holding.ApplySubscription(100m);
        holding.ApplySubscription(50m);

        holding.Units.Should().Be(150m);
    }

    [Fact]
    public void ApplySubscription_WithZeroUnits_ThrowsArgumentException()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        var act = () => holding.ApplySubscription(0m);

        act.Should().Throw<ArgumentException>().WithParameterName("units");
    }

    [Fact]
    public void ApplySubscription_WithNegativeUnits_ThrowsArgumentException()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        var act = () => holding.ApplySubscription(-10m);

        act.Should().Throw<ArgumentException>().WithParameterName("units");
    }

    [Fact]
    public void ApplyRedemption_SubtractsUnits()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.ApplySubscription(100m);

        holding.ApplyRedemption(40m);

        holding.Units.Should().Be(60m);
        holding.Status.Should().Be(HoldingStatus.Active);
    }

    [Fact]
    public void ApplyRedemption_WhenFullRedemption_ClosesHolding()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.ApplySubscription(100m);

        holding.ApplyRedemption(100m);

        holding.Units.Should().Be(0m);
        holding.Status.Should().Be(HoldingStatus.Closed);
    }

    [Fact]
    public void ApplyRedemption_WhenExceedsBalance_ThrowsInvalidOperationException()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.ApplySubscription(50m);

        var act = () => holding.ApplyRedemption(100m);

        act.Should().Throw<InvalidOperationException>().WithMessage("*50*");
    }

    [Fact]
    public void ApplyRedemption_WithZeroUnits_ThrowsArgumentException()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.ApplySubscription(100m);

        var act = () => holding.ApplyRedemption(0m);

        act.Should().Throw<ArgumentException>().WithParameterName("units");
    }

    [Fact]
    public void ApplyTransfer_DelegatesToApplyRedemption()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.ApplySubscription(100m);

        holding.ApplyTransfer(30m);

        holding.Units.Should().Be(70m);
    }

    [Fact]
    public void Freeze_WhenActive_SetsStatusToFrozen()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        holding.Freeze();

        holding.Status.Should().Be(HoldingStatus.Frozen);
    }

    [Fact]
    public void Freeze_WhenAlreadyFrozen_RemainsUnchanged()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.Freeze();

        holding.Freeze(); // second call — no-op

        holding.Status.Should().Be(HoldingStatus.Frozen);
    }

    [Fact]
    public void Unfreeze_WhenFrozen_SetsStatusToActive()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);
        holding.Freeze();

        holding.Unfreeze();

        holding.Status.Should().Be(HoldingStatus.Active);
    }

    [Fact]
    public void Unfreeze_WhenActive_RemainsUnchanged()
    {
        var holding = Holding.Create(ValidTenantId, ValidAccountId, ValidClassId);

        holding.Unfreeze(); // no-op

        holding.Status.Should().Be(HoldingStatus.Active);
    }
}
