using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class InvestorDocument : BaseEntity, IAuditableEntity
{
    public Guid InvestorId { get; private set; }
    public Guid TenantId { get; private set; }
    public DocumentType DocumentType { get; private set; }
    public string DocumentNumber { get; private set; } = string.Empty;
    public string IssueCountry { get; private set; } = string.Empty;
    public string? IssueState { get; private set; }
    public DateOnly? IssueDate { get; private set; }
    public DateOnly? ExpiryDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Investor Investor { get; private set; } = null!;

    private InvestorDocument() { }

    public static InvestorDocument Create(
        Guid investorId,
        Guid tenantId,
        DocumentType documentType,
        string documentNumber,
        string issueCountry,
        string? issueState = null,
        DateOnly? issueDate = null,
        DateOnly? expiryDate = null)
    {
        if (investorId == Guid.Empty) throw new ArgumentException("InvestorId required.", nameof(investorId));
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (string.IsNullOrWhiteSpace(documentNumber)) throw new ArgumentException("DocumentNumber required.", nameof(documentNumber));
        if (string.IsNullOrWhiteSpace(issueCountry)) throw new ArgumentException("IssueCountry required.", nameof(issueCountry));

        return new InvestorDocument
        {
            InvestorId = investorId,
            TenantId = tenantId,
            DocumentType = documentType,
            DocumentNumber = documentNumber.Trim(),
            IssueCountry = issueCountry.Trim().ToUpperInvariant(),
            IssueState = issueState?.Trim(),
            IssueDate = issueDate,
            ExpiryDate = expiryDate
        };
    }
}
