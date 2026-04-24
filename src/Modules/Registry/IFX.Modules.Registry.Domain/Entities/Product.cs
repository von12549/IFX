using IFX.BuildingBlocks.Domain;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Entities;

public class Product : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string ProductCode { get; private set; } = string.Empty;
    public string ProductName { get; private set; } = string.Empty;
    public ProductType ProductType { get; private set; }
    public string BaseCurrency { get; private set; } = string.Empty;
    public string? ApirCode { get; private set; }
    public string? Isin { get; private set; }
    public string? RegulatorSchemeNumber { get; private set; }
    public string? PdsReference { get; private set; }
    public string? IssuerName { get; private set; }
    public DateOnly InceptionDate { get; private set; }
    public DateOnly? WindUpDate { get; private set; }
    public ProductStatus Status { get; private set; } = ProductStatus.Active;
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private readonly List<Fund> _funds = new();
    public IReadOnlyCollection<Fund> Funds => _funds.AsReadOnly();

    private Product() { } // For EF Core

    public static Product Create(
        Guid tenantId,
        string productCode,
        string productName,
        ProductType productType,
        string baseCurrency,
        DateOnly inceptionDate,
        string? apirCode = null,
        string? isin = null,
        string? regulatorSchemeNumber = null,
        string? pdsReference = null,
        string? issuerName = null)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        if (string.IsNullOrWhiteSpace(productCode))
            throw new ArgumentException("Product code cannot be empty.", nameof(productCode));

        if (string.IsNullOrWhiteSpace(productName))
            throw new ArgumentException("Product name cannot be empty.", nameof(productName));

        if (string.IsNullOrWhiteSpace(baseCurrency) || baseCurrency.Length != 3)
            throw new ArgumentException("Base currency must be a 3-letter ISO 4217 code.", nameof(baseCurrency));

        return new Product
        {
            TenantId = tenantId,
            ProductCode = productCode.Trim().ToUpperInvariant(),
            ProductName = productName.Trim(),
            ProductType = productType,
            BaseCurrency = baseCurrency.Trim().ToUpperInvariant(),
            InceptionDate = inceptionDate,
            ApirCode = apirCode?.Trim().ToUpperInvariant(),
            Isin = isin?.Trim().ToUpperInvariant(),
            RegulatorSchemeNumber = regulatorSchemeNumber?.Trim(),
            PdsReference = pdsReference?.Trim(),
            IssuerName = issuerName?.Trim(),
            Status = ProductStatus.Active
        };
    }

    public void Update(
        string productName,
        string? apirCode,
        string? isin,
        string? regulatorSchemeNumber,
        string? pdsReference,
        string? issuerName,
        DateOnly? windUpDate)
    {
        if (string.IsNullOrWhiteSpace(productName))
            throw new ArgumentException("Product name cannot be empty.", nameof(productName));

        ProductName = productName.Trim();
        ApirCode = apirCode?.Trim().ToUpperInvariant();
        Isin = isin?.Trim().ToUpperInvariant();
        RegulatorSchemeNumber = regulatorSchemeNumber?.Trim();
        PdsReference = pdsReference?.Trim();
        IssuerName = issuerName?.Trim();
        WindUpDate = windUpDate;
    }

    public void Close()
    {
        Status = ProductStatus.Closed;
    }

    public void Suspend()
    {
        Status = ProductStatus.Suspended;
    }

    public void Reactivate()
    {
        Status = ProductStatus.Active;
    }
}
