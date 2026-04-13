using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class InvestmentAccount : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string AccountNumber { get; private set; } = string.Empty;
    public InvestmentAccountType AccountType { get; private set; }
    public EntityStatus Status { get; private set; } = EntityStatus.Active;
    public DateOnly? CertificateDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<PartyInvestmentAccountLink> PartyLinks { get; private set; } = new List<PartyInvestmentAccountLink>();
    public ICollection<AdvisorInvestmentAccountLink> AdvisorLinks { get; private set; } = new List<AdvisorInvestmentAccountLink>();

    private InvestmentAccount() { }

    public static InvestmentAccount Create(Guid tenantId, string accountNumber, InvestmentAccountType accountType, DateOnly? certificateDate = null)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));
        if (string.IsNullOrWhiteSpace(accountNumber))
            throw new ArgumentException("AccountNumber cannot be empty.", nameof(accountNumber));

        return new InvestmentAccount
        {
            TenantId = tenantId,
            AccountNumber = accountNumber.Trim().ToUpperInvariant(),
            AccountType = accountType,
            CertificateDate = certificateDate,
            Status = EntityStatus.Active
        };
    }

    public void Update(string accountNumber, InvestmentAccountType accountType, DateOnly? certificateDate)
    {
        if (string.IsNullOrWhiteSpace(accountNumber))
            throw new ArgumentException("AccountNumber cannot be empty.", nameof(accountNumber));

        AccountNumber = accountNumber.Trim().ToUpperInvariant();
        AccountType = accountType;
        CertificateDate = certificateDate;
    }

    public void Deactivate() => Status = EntityStatus.Inactive;
    public void Lock() => Status = EntityStatus.Locked;
    public void Activate() => Status = EntityStatus.Active;
}
