using IFX.BuildingBlocks.Domain;
using IFX.Modules.Transaction.Domain.Enums;

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
    public decimal? Units { get; private set; }
    public decimal? NAVPrice { get; private set; }
    public DateOnly TradeDate { get; private set; }
    public DateOnly? SettlementDate { get; private set; }
    public TransactionStatus Status { get; private set; } = TransactionStatus.Pending;
    public string? FailureReason { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Transaction() { }

    private static Transaction CreateBase(
        Guid tenantId, TransactionType type, Guid investmentAccountId,
        Guid fundId, Guid classId, Guid? targetClassId, decimal amount, DateOnly tradeDate)
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
            TradeDate = tradeDate,
            Status = TransactionStatus.Pending
        };
    }

    public static Transaction CreateSubscription(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Subscription, investmentAccountId, fundId, classId, null, amount, tradeDate);

    public static Transaction CreateRedemption(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Redemption, investmentAccountId, fundId, classId, null, amount, tradeDate);

    public static Transaction CreateTransfer(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, Guid targetClassId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Transfer, investmentAccountId, fundId, classId, targetClassId, amount, tradeDate);

    public static Transaction CreateSwitch(Guid tenantId, Guid investmentAccountId, Guid fundId, Guid classId, Guid targetClassId, decimal amount, DateOnly tradeDate)
        => CreateBase(tenantId, TransactionType.Switch, investmentAccountId, fundId, classId, targetClassId, amount, tradeDate);

    public void Process(decimal navPrice)
    {
        if (Status != TransactionStatus.Pending && Status != TransactionStatus.Processing)
            throw new InvalidOperationException($"Cannot process transaction in status {Status}.");
        if (navPrice <= 0) throw new ArgumentException("NAVPrice must be positive.", nameof(navPrice));

        NAVPrice = navPrice;
        Units = Math.Round(Amount / navPrice, 8);
        Status = TransactionStatus.Processed;
    }

    public void Cancel(string? reason = null)
    {
        if (Status == TransactionStatus.Settled || Status == TransactionStatus.Cancelled || Status == TransactionStatus.Failed)
            throw new InvalidOperationException($"Cannot cancel transaction in status {Status}.");

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
            throw new InvalidOperationException($"Cannot settle transaction in status {Status}.");
        Status = TransactionStatus.Settled;
        SettlementDate = settlementDate ?? DateOnly.FromDateTime(DateTime.UtcNow);
    }
}
