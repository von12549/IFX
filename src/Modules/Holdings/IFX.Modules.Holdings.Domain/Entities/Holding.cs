using IFX.BuildingBlocks.Domain;
using IFX.Modules.Holdings.Domain.Enums;

namespace IFX.Modules.Holdings.Domain.Entities;

public class Holding : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid InvestmentAccountId { get; private set; }
    public Guid ClassId { get; private set; }
    public decimal Units { get; private set; }
    public HoldingStatus Status { get; private set; } = HoldingStatus.Active;
    public DateTimeOffset? LastTransactionAt { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private Holding() { }

    public static Holding Create(Guid tenantId, Guid investmentAccountId, Guid classId)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (investmentAccountId == Guid.Empty) throw new ArgumentException("InvestmentAccountId required.", nameof(investmentAccountId));
        if (classId == Guid.Empty) throw new ArgumentException("ClassId required.", nameof(classId));

        return new Holding
        {
            TenantId = tenantId,
            InvestmentAccountId = investmentAccountId,
            ClassId = classId,
            Units = 0m,
            Status = HoldingStatus.Active
        };
    }

    public void ApplySubscription(decimal units)
    {
        if (units <= 0) throw new ArgumentException("Units must be positive.", nameof(units));
        Units += units;
        LastTransactionAt = DateTimeOffset.UtcNow;
    }

    public void ApplyRedemption(decimal units)
    {
        if (units <= 0) throw new ArgumentException("Units must be positive.", nameof(units));
        if (units > Units) throw new DomainRuleViolationException($"Cannot redeem {units} units; holding only has {Units}.");
        Units -= units;
        LastTransactionAt = DateTimeOffset.UtcNow;
        if (Units == 0) Status = HoldingStatus.Closed;
    }

    public void ApplyTransfer(decimal units) => ApplyRedemption(units);

    public void Freeze()
    {
        if (Status == HoldingStatus.Active) Status = HoldingStatus.Frozen;
    }

    public void Unfreeze()
    {
        if (Status == HoldingStatus.Frozen) Status = HoldingStatus.Active;
    }
}
