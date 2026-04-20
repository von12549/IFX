using IFX.BuildingBlocks.Domain;
using IFX.Modules.Transaction.Domain.Enums;

namespace IFX.Modules.Transaction.Domain.Entities;

public class Order : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string OrderReference { get; private set; } = string.Empty;
    public string? DealReference { get; private set; }
    public OrderType OrderType { get; private set; }
    public OrderStatus Status { get; private set; } = OrderStatus.Submitted;
    public string? RejectionReason { get; private set; }
    public DateOnly? ExpectedTradeDate { get; private set; }
    public DateOnly? ExpectedSettlementDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private readonly List<Transaction> _legs = new();
    public IReadOnlyList<Transaction> Legs => _legs.AsReadOnly();

    private Order() { }

    public static Order CreateSubscriptionOrder(
        Guid tenantId, string orderReference,
        Guid investmentAccountId, Guid fundId, Guid classId,
        decimal amount, string currency, DateOnly tradeDate)
    {
        var order = CreateBase(tenantId, orderReference, OrderType.SubscriptionOrder);
        var leg = Transaction.CreateForOrder(
            tenantId, TransactionType.Subscription, investmentAccountId,
            fundId, classId, amount, currency, tradeDate, order.Id);
        order._legs.Add(leg);
        return order;
    }

    public static Order CreateRedemptionOrder(
        Guid tenantId, string orderReference,
        Guid investmentAccountId, Guid fundId, Guid classId,
        decimal amount, string currency, DateOnly tradeDate)
    {
        var order = CreateBase(tenantId, orderReference, OrderType.RedemptionOrder);
        var leg = Transaction.CreateForOrder(
            tenantId, TransactionType.Redemption, investmentAccountId,
            fundId, classId, amount, currency, tradeDate, order.Id);
        order._legs.Add(leg);
        return order;
    }

    public static Order CreateSwitchOrder(
        Guid tenantId, string orderReference,
        Guid investmentAccountId,
        Guid fromFundId, Guid fromClassId,
        Guid toFundId, Guid toClassId,
        decimal amount, string currency, DateOnly tradeDate)
    {
        var order = CreateBase(tenantId, orderReference, OrderType.SwitchOrder);

        var redemptionLeg = Transaction.CreateForOrder(
            tenantId, TransactionType.Redemption, investmentAccountId,
            fromFundId, fromClassId, amount, currency, tradeDate, order.Id, legId: "redemption");

        var subscriptionLeg = Transaction.CreateForOrder(
            tenantId, TransactionType.Subscription, investmentAccountId,
            toFundId, toClassId, amount, currency, tradeDate, order.Id, legId: "subscription");

        order._legs.Add(redemptionLeg);
        order._legs.Add(subscriptionLeg);
        return order;
    }

    public void Accept(string dealReference, DateOnly? expectedTradeDate = null, DateOnly? expectedSettlementDate = null)
    {
        if (Status != OrderStatus.Submitted)
            throw new InvalidOperationException($"Cannot accept an order in status {Status}.");
        if (string.IsNullOrWhiteSpace(dealReference))
            throw new ArgumentException("Deal reference is required to accept an order.", nameof(dealReference));

        Status = OrderStatus.Accepted;
        DealReference = dealReference;
        ExpectedTradeDate = expectedTradeDate;
        ExpectedSettlementDate = expectedSettlementDate;
    }

    public void Reject(string reason)
    {
        if (Status != OrderStatus.Submitted && Status != OrderStatus.Accepted)
            throw new InvalidOperationException($"Cannot reject an order in status {Status}.");
        if (string.IsNullOrWhiteSpace(reason))
            throw new ArgumentException("Rejection reason is required.", nameof(reason));

        Status = OrderStatus.Rejected;
        RejectionReason = reason;
    }

    public void Confirm()
    {
        if (Status != OrderStatus.Accepted)
            throw new InvalidOperationException($"Cannot confirm an order in status {Status}. Order must be Accepted first.");

        Status = OrderStatus.PriceConfirmed;
    }

    public void Cancel(string? reason = null)
    {
        if (Status == OrderStatus.PriceConfirmed || Status == OrderStatus.Cancelled || Status == OrderStatus.Rejected)
            throw new InvalidOperationException($"Cannot cancel an order in status {Status}.");

        Status = OrderStatus.Cancelled;
        RejectionReason = reason;
    }

    private static Order CreateBase(Guid tenantId, string orderReference, OrderType orderType)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId is required.", nameof(tenantId));
        if (string.IsNullOrWhiteSpace(orderReference)) throw new ArgumentException("Order reference is required.", nameof(orderReference));
        if (orderReference.Length > 35) throw new ArgumentException("Order reference must not exceed 35 characters.", nameof(orderReference));

        return new Order
        {
            TenantId = tenantId,
            OrderReference = orderReference,
            OrderType = orderType,
            Status = OrderStatus.Submitted
        };
    }
}
