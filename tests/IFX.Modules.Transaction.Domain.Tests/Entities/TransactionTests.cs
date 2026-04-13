using IFX.Modules.Transaction.Domain.Enums;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Domain.Tests.Entities;

public class TransactionTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid InvestmentAccountId = Guid.NewGuid();
    private static readonly Guid FundId = Guid.NewGuid();
    private static readonly Guid ClassId = Guid.NewGuid();
    private static readonly Guid TargetClassId = Guid.NewGuid();
    private static readonly DateOnly TradeDate = DateOnly.FromDateTime(DateTime.UtcNow);

    // --- Factory methods ---

    [Fact]
    public void CreateSubscription_WithValidParameters_ReturnsTransaction()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 10000m, TradeDate);

        tx.Should().NotBeNull();
        tx.Id.Should().NotBeEmpty();
        tx.TenantId.Should().Be(TenantId);
        tx.Type.Should().Be(TransactionType.Subscription);
        tx.Amount.Should().Be(10000m);
        tx.Status.Should().Be(TransactionStatus.Pending);
        tx.TargetClassId.Should().BeNull();
        tx.Units.Should().BeNull();
        tx.NAVPrice.Should().BeNull();
    }

    [Fact]
    public void CreateRedemption_SetsTypeToRedemption()
    {
        var tx = TxEntity.CreateRedemption(TenantId, InvestmentAccountId, FundId, ClassId, 5000m, TradeDate);

        tx.Type.Should().Be(TransactionType.Redemption);
        tx.TargetClassId.Should().BeNull();
    }

    [Fact]
    public void CreateTransfer_SetsTypeAndTargetClass()
    {
        var tx = TxEntity.CreateTransfer(TenantId, InvestmentAccountId, FundId, ClassId, TargetClassId, 3000m, TradeDate);

        tx.Type.Should().Be(TransactionType.Transfer);
        tx.TargetClassId.Should().Be(TargetClassId);
    }

    [Fact]
    public void CreateSwitch_SetsTypeAndTargetClass()
    {
        var tx = TxEntity.CreateSwitch(TenantId, InvestmentAccountId, FundId, ClassId, TargetClassId, 2000m, TradeDate);

        tx.Type.Should().Be(TransactionType.Switch);
        tx.TargetClassId.Should().Be(TargetClassId);
    }

    [Fact]
    public void CreateSubscription_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => TxEntity.CreateSubscription(Guid.Empty, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void CreateSubscription_WithNonPositiveAmount_ThrowsArgumentException(decimal amount)
    {
        var act = () => TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, amount, TradeDate);

        act.Should().Throw<ArgumentException>().WithParameterName("amount");
    }

    // --- Process ---

    [Fact]
    public void Process_WithValidNav_CalculatesUnitsAndChangesStatus()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 10000m, TradeDate);

        tx.Process(navPrice: 10m);

        tx.NAVPrice.Should().Be(10m);
        tx.Units.Should().Be(1000m); // 10000 / 10
        tx.Status.Should().Be(TransactionStatus.Processed);
    }

    [Fact]
    public void Process_RoundsUnitsToEightDecimalPlaces()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        tx.Process(navPrice: 3m);

        tx.Units.Should().Be(Math.Round(1000m / 3m, 8));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void Process_WithNonPositiveNav_ThrowsArgumentException(decimal navPrice)
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        var act = () => tx.Process(navPrice);

        act.Should().Throw<ArgumentException>().WithParameterName("navPrice");
    }

    [Fact]
    public void Process_WhenAlreadyProcessed_ThrowsInvalidOperationException()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);
        tx.Process(10m);

        var act = () => tx.Process(10m);

        act.Should().Throw<InvalidOperationException>();
    }

    // --- Cancel ---

    [Fact]
    public void Cancel_WhenPending_SetsStatusToCancelled()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        tx.Cancel("User requested");

        tx.Status.Should().Be(TransactionStatus.Cancelled);
        tx.FailureReason.Should().Be("User requested");
    }

    [Fact]
    public void Cancel_WithNoReason_SetsStatusToCancelled()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        tx.Cancel();

        tx.Status.Should().Be(TransactionStatus.Cancelled);
        tx.FailureReason.Should().BeNull();
    }

    [Fact]
    public void Cancel_WhenSettled_ThrowsInvalidOperationException()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);
        tx.Process(10m);
        tx.Settle();

        var act = () => tx.Cancel();

        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_WhenAlreadyCancelled_ThrowsInvalidOperationException()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);
        tx.Cancel();

        var act = () => tx.Cancel();

        act.Should().Throw<InvalidOperationException>();
    }

    // --- Fail ---

    [Fact]
    public void Fail_SetsStatusToFailedWithReason()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        tx.Fail("Validation failed");

        tx.Status.Should().Be(TransactionStatus.Failed);
        tx.FailureReason.Should().Be("Validation failed");
    }

    // --- Settle ---

    [Fact]
    public void Settle_WhenProcessed_SetsStatusToSettled()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);
        tx.Process(10m);

        tx.Settle();

        tx.Status.Should().Be(TransactionStatus.Settled);
        tx.SettlementDate.Should().NotBeNull();
    }

    [Fact]
    public void Settle_WithExplicitDate_UsesProvidedDate()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);
        tx.Process(10m);
        var settlementDate = new DateOnly(2025, 6, 1);

        tx.Settle(settlementDate);

        tx.SettlementDate.Should().Be(settlementDate);
    }

    [Fact]
    public void Settle_WhenPending_ThrowsInvalidOperationException()
    {
        var tx = TxEntity.CreateSubscription(TenantId, InvestmentAccountId, FundId, ClassId, 1000m, TradeDate);

        var act = () => tx.Settle();

        act.Should().Throw<InvalidOperationException>();
    }
}
