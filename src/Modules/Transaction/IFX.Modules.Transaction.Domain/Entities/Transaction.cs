using IFX.BuildingBlocks.Domain;
using IFX.Modules.Transaction.Domain.Enums;
using IFX.Modules.Transaction.Domain.ValueObjects;

namespace IFX.Modules.Transaction.Domain.Entities;

public class Transaction : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public TransactionType Type { get; private set; }
    public Guid InvestmentAccountId { get; private set; }
    public Guid FundId { get; private set; }
    public Guid ClassId { get; private set; }
    public Guid? TargetClassId { get; private set; }
    public decimal Amount { get; private set; }
    public string Currency { get; private set; } = "AUD";
    public decimal? Units { get; private set; }
    public decimal? NAVPrice { get; private set; }
    public DateOnly TradeDate { get; private set; }
    public DateOnly? SettlementDate { get; private set; }
    public TransactionStatus Status { get; private set; } = TransactionStatus.Pending;
    public string? FailureReason { get; private set; }

    // Order linkage (null for legacy direct transactions)
    public Guid? OrderId { get; private set; }
    public string? LegId { get; private set; }

    // Financial detail (populated on Order Confirm)
    public ExternalFundIdentifier? ExternalFundIdentifier { get; private set; }
    public DealingPriceDetails? DealingPriceDetails { get; private set; }
    public List<ChargeDetail> ChargeDetails { get; private set; } = new();
    public List<CommissionDetail> CommissionDetails { get; private set; } = new();
    public List<TaxDetail> TaxDetails { get; private set; } = new();

    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private Transaction() { }

    private static Transaction CreateBase(
        Guid tenantId, TransactionType type, Guid investmentAccountId,
        Guid fundId, Guid classId, Guid? targetClassId,
        decimal amount, string currency, DateOnly tradeDate)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (investmentAccountId == Guid.Empty) throw new ArgumentException("InvestmentAccountId required.", nameof(investmentAccountId));
        if (amount <= 0) throw new ArgumentException("Amount must be positive.", nameof(amount));

        return new Transaction
        {
            TenantId = tenantId,
            Type = type,
            InvestmentAccountId = investmentAccountId,
            FundId = fundId,
            ClassId = classId,
            TargetClassId = targetClassId,
            Amount = amount,
            Currency = string.IsNullOrWhiteSpace(currency) ? "AUD" : currency.ToUpperInvariant(),
            TradeDate = tradeDate,
            Status = TransactionStatus.Pending
        };
    }

    // Legacy direct-create factory methods (no Order parent)
    public static Transaction CreateSubscription(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Subscription, investmentAccountId, fundId, classId, null, amount, "AUD", tradeDate);

    public static Transaction CreateRedemption(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Redemption, investmentAccountId, fundId, classId, null, amount, "AUD", tradeDate);

    public static Transaction CreateTransfer(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, Guid targetClassId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Transfer, investmentAccountId, fundId, classId, targetClassId, amount, "AUD", tradeDate);

    public static Transaction CreateSwitch(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, Guid targetClassId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Switch, investmentAccountId, fundId, classId, targetClassId, amount, "AUD", tradeDate);

    // Order-leg factory method — called by Order aggregate
    internal static Transaction CreateForOrder(
        Guid tenantId, TransactionType type, Guid investmentAccountId,
        Guid fundId, Guid classId, decimal amount, string currency,
        DateOnly tradeDate, Guid orderId, string? legId = null)
    {
        var tx = CreateBase(tenantId, type, investmentAccountId, fundId, classId, null, amount, currency, tradeDate);
        tx.OrderId = orderId;
        tx.LegId = legId;
        return tx;
    }

    public void Process(decimal navPrice)
    {
        if (Status != TransactionStatus.Pending && Status != TransactionStatus.Processing)
            throw new DomainRuleViolationException($"Cannot process transaction in status {Status}.");
        if (navPrice <= 0) throw new ArgumentException("NAVPrice must be positive.", nameof(navPrice));

        NAVPrice = navPrice;
        Units = Math.Round(Amount / navPrice, 8);
        Status = TransactionStatus.Processed;
    }

    public void Confirm(decimal navPrice, decimal units, DealingPriceDetails? priceDetails = null,
        IEnumerable<ChargeDetail>? charges = null, IEnumerable<CommissionDetail>? commissions = null,
        IEnumerable<TaxDetail>? taxes = null, DateOnly? settlementDate = null)
    {
        if (Status != TransactionStatus.Pending && Status != TransactionStatus.Processing)
            throw new DomainRuleViolationException($"Cannot confirm transaction in status {Status}.");
        if (navPrice <= 0) throw new ArgumentException("NAVPrice must be positive.", nameof(navPrice));
        if (units <= 0) throw new ArgumentException("Units must be positive.", nameof(units));

        NAVPrice = navPrice;
        Units = units;
        DealingPriceDetails = priceDetails;
        if (charges != null) ChargeDetails = charges.ToList();
        if (commissions != null) CommissionDetails = commissions.ToList();
        if (taxes != null) TaxDetails = taxes.ToList();
        SettlementDate = settlementDate;
        Status = TransactionStatus.Processed;
    }

    public void Cancel(string? reason = null)
    {
        if (Status == TransactionStatus.Settled || Status == TransactionStatus.Cancelled || Status == TransactionStatus.Failed)
            throw new DomainRuleViolationException($"Cannot cancel transaction in status {Status}.");

        Status = TransactionStatus.Cancelled;
        FailureReason = reason;
    }

    public void Fail(string reason)
    {
        Status = TransactionStatus.Failed;
        FailureReason = reason;
    }

    public void Settle(DateOnly? settlementDate = null)
    {
        if (Status != TransactionStatus.Processed)
            throw new DomainRuleViolationException($"Cannot settle transaction in status {Status}.");
        Status = TransactionStatus.Settled;
        SettlementDate = settlementDate ?? DateOnly.FromDateTime(DateTime.UtcNow);
    }

    public void SetExternalFundIdentifier(ExternalFundIdentifier identifier) =>
        ExternalFundIdentifier = identifier;
}
