using IFX.Modules.Holdings.Domain.Common;
using IFX.Modules.Holdings.Domain.Enums;

namespace IFX.Modules.Holdings.Domain.Entities;

public class Holding : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid InvestorId { get; private set; }
    public Guid ClassId { get; private set; }
    public decimal Units { get; private set; }
    public HoldingStatus Status { get; private set; } = HoldingStatus.Active;
    public DateTime? LastTransactionAt { get; private set; }
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Holding() { } // For EF Core

    public static Holding Create(Guid tenantId, Guid investorId, Guid classId)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (investorId == Guid.Empty) throw new ArgumentException("InvestorId required.", nameof(investorId));
        if (classId == Guid.Empty) throw new ArgumentException("ClassId required.", nameof(classId));

        return new Holding
        {
            TenantId = tenantId,
            InvestorId = investorId,
            ClassId = classId,
            Units = 0m,
            Status = HoldingStatus.Active
        };
    }

    public void ApplySubscription(decimal units)
    {
        if (units <= 0) throw new ArgumentException("Units must be positive.", nameof(units));
        Units += units;
        LastTransactionAt = DateTime.UtcNow;
    }

    public void ApplyRedemption(decimal units)
    {
        if (units <= 0) throw new ArgumentException("Units must be positive.", nameof(units));
        if (units > Units) throw new InvalidOperationException($"Cannot redeem {units} units; holding only has {Units}.");
        Units -= units;
        LastTransactionAt = DateTime.UtcNow;
        if (Units == 0) Status = HoldingStatus.Closed;
    }

    public void ApplyTransfer(decimal units)
    {
        // Transfer out: treat as redemption from this class
        ApplyRedemption(units);
    }

    public void Freeze()
    {
        if (Status == HoldingStatus.Active)
            Status = HoldingStatus.Frozen;
    }

    public void Unfreeze()
    {
        if (Status == HoldingStatus.Frozen)
            Status = HoldingStatus.Active;
    }
}
