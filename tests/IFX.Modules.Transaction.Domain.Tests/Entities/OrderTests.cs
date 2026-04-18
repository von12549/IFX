using IFX.Modules.Transaction.Domain.Entities;
using IFX.Modules.Transaction.Domain.Enums;

namespace IFX.Modules.Transaction.Domain.Tests.Entities;

public class OrderTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid InvestmentAccountId = Guid.NewGuid();
    private static readonly Guid FundId = Guid.NewGuid();
    private static readonly Guid ClassId = Guid.NewGuid();
    private static readonly Guid ToFundId = Guid.NewGuid();
    private static readonly Guid ToClassId = Guid.NewGuid();
    private static readonly DateOnly TradeDate = DateOnly.FromDateTime(DateTime.UtcNow);

    // --- Factory methods ---

    [Fact]
    public void CreateSubscriptionOrder_WithValidParams_ReturnsOrderWithOneLeg()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        order.Should().NotBeNull();
        order.Id.Should().NotBeEmpty();
        order.TenantId.Should().Be(TenantId);
        order.OrderReference.Should().Be("ORD-001");
        order.OrderType.Should().Be(OrderType.SubscriptionOrder);
        order.Status.Should().Be(OrderStatus.Submitted);
        order.Legs.Should().HaveCount(1);
        order.Legs[0].Type.Should().Be(TransactionType.Subscription);
        order.Legs[0].OrderId.Should().Be(order.Id);
        order.Legs[0].Currency.Should().Be("AUD");
    }

    [Fact]
    public void CreateRedemptionOrder_WithValidParams_ReturnsOrderWithOneLeg()
    {
        var order = Order.CreateRedemptionOrder(
            TenantId, "ORD-002", InvestmentAccountId, FundId, ClassId, 5000m, "AUD", TradeDate);

        order.OrderType.Should().Be(OrderType.RedemptionOrder);
        order.Legs.Should().HaveCount(1);
        order.Legs[0].Type.Should().Be(TransactionType.Redemption);
    }

    [Fact]
    public void CreateSwitchOrder_WithValidParams_ReturnsTwoLegs()
    {
        var order = Order.CreateSwitchOrder(
            TenantId, "ORD-003", InvestmentAccountId,
            FundId, ClassId, ToFundId, ToClassId,
            8000m, "AUD", TradeDate);

        order.OrderType.Should().Be(OrderType.SwitchOrder);
        order.Legs.Should().HaveCount(2);

        var redemptionLeg = order.Legs.First(l => l.Type == TransactionType.Redemption);
        var subscriptionLeg = order.Legs.First(l => l.Type == TransactionType.Subscription);

        redemptionLeg.ClassId.Should().Be(ClassId);
        redemptionLeg.LegId.Should().Be("redemption");

        subscriptionLeg.ClassId.Should().Be(ToClassId);
        subscriptionLeg.LegId.Should().Be("subscription");

        redemptionLeg.OrderId.Should().Be(order.Id);
        subscriptionLeg.OrderId.Should().Be(order.Id);
    }

    [Fact]
    public void CreateSubscriptionOrder_WithEmptyTenantId_ThrowsArgumentException()
    {
        var act = () => Order.CreateSubscriptionOrder(
            Guid.Empty, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        act.Should().Throw<ArgumentException>().WithParameterName("tenantId");
    }

    [Fact]
    public void CreateSubscriptionOrder_WithEmptyOrderReference_ThrowsArgumentException()
    {
        var act = () => Order.CreateSubscriptionOrder(
            TenantId, "", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void CreateSubscriptionOrder_WithOrderReferenceOver35Chars_ThrowsArgumentException()
    {
        var longRef = new string('X', 36);
        var act = () => Order.CreateSubscriptionOrder(
            TenantId, longRef, InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        act.Should().Throw<ArgumentException>();
    }

    // --- Accept ---

    [Fact]
    public void Accept_WhenSubmitted_ChangesStatusToAccepted()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        order.Accept("DEAL-001");

        order.Status.Should().Be(OrderStatus.Accepted);
        order.DealReference.Should().Be("DEAL-001");
    }

    [Fact]
    public void Accept_WithExpectedDates_StoresDates()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        var expectedTrade = new DateOnly(2026, 5, 1);
        var expectedSettlement = new DateOnly(2026, 5, 3);

        order.Accept("DEAL-001", expectedTrade, expectedSettlement);

        order.ExpectedTradeDate.Should().Be(expectedTrade);
        order.ExpectedSettlementDate.Should().Be(expectedSettlement);
    }

    [Fact]
    public void Accept_WithEmptyDealReference_ThrowsArgumentException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        var act = () => order.Accept("");

        act.Should().Throw<ArgumentException>().WithParameterName("dealReference");
    }

    [Fact]
    public void Accept_WhenAlreadyAccepted_ThrowsInvalidOperationException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");

        var act = () => order.Accept("DEAL-002");

        act.Should().Throw<InvalidOperationException>();
    }

    // --- Reject ---

    [Fact]
    public void Reject_WhenSubmitted_ChangesStatusToRejected()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        order.Reject("Unknown ISIN");

        order.Status.Should().Be(OrderStatus.Rejected);
        order.RejectionReason.Should().Be("Unknown ISIN");
    }

    [Fact]
    public void Reject_WhenAccepted_ChangesStatusToRejected()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");

        order.Reject("Back office rejection");

        order.Status.Should().Be(OrderStatus.Rejected);
    }

    [Fact]
    public void Reject_WhenAlreadyConfirmed_ThrowsInvalidOperationException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");
        order.Confirm();

        var act = () => order.Reject("Too late");

        act.Should().Throw<InvalidOperationException>();
    }

    // --- Confirm ---

    [Fact]
    public void Confirm_WhenAccepted_ChangesStatusToPriceConfirmed()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");

        order.Confirm();

        order.Status.Should().Be(OrderStatus.PriceConfirmed);
    }

    [Fact]
    public void Confirm_WhenSubmitted_ThrowsInvalidOperationException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        var act = () => order.Confirm();

        act.Should().Throw<InvalidOperationException>().WithMessage("*Accepted*");
    }

    // --- Cancel ---

    [Fact]
    public void Cancel_WhenSubmitted_ChangesStatusToCancelled()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);

        order.Cancel("Investor withdrew");

        order.Status.Should().Be(OrderStatus.Cancelled);
        order.RejectionReason.Should().Be("Investor withdrew");
    }

    [Fact]
    public void Cancel_WhenPriceConfirmed_ThrowsInvalidOperationException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Accept("DEAL-001");
        order.Confirm();

        var act = () => order.Cancel();

        act.Should().Throw<InvalidOperationException>();
    }

    [Fact]
    public void Cancel_WhenAlreadyCancelled_ThrowsInvalidOperationException()
    {
        var order = Order.CreateSubscriptionOrder(
            TenantId, "ORD-001", InvestmentAccountId, FundId, ClassId, 10000m, "AUD", TradeDate);
        order.Cancel();

        var act = () => order.Cancel();

        act.Should().Throw<InvalidOperationException>();
    }
}
