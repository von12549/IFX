using IFX.Modules.Registry.Domain.Common;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Entities;

public class Fund : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string FundCode { get; private set; } = string.Empty;
    public string FundName { get; private set; } = string.Empty;
    public FundType FundType { get; private set; }
    public string BaseCurrency { get; private set; } = string.Empty;
    public DateOnly InceptionDate { get; private set; }
    public FundStatus Status { get; private set; } = FundStatus.Active;
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Fund() { } // For EF Core

    public static Fund Create(
        Guid tenantId,
        string fundCode,
        string fundName,
        FundType fundType,
        string baseCurrency,
        DateOnly inceptionDate)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        if (string.IsNullOrWhiteSpace(fundCode))
            throw new ArgumentException("Fund code cannot be empty.", nameof(fundCode));

        if (string.IsNullOrWhiteSpace(fundName))
            throw new ArgumentException("Fund name cannot be empty.", nameof(fundName));

        if (string.IsNullOrWhiteSpace(baseCurrency) || baseCurrency.Length != 3)
            throw new ArgumentException("Base currency must be a 3-letter ISO 4217 code.", nameof(baseCurrency));

        return new Fund
        {
            TenantId = tenantId,
            FundCode = fundCode.Trim().ToUpperInvariant(),
            FundName = fundName.Trim(),
            FundType = fundType,
            BaseCurrency = baseCurrency.Trim().ToUpperInvariant(),
            InceptionDate = inceptionDate,
            Status = FundStatus.Active
        };
    }

    public void Update(string fundName, FundType fundType, string baseCurrency)
    {
        if (string.IsNullOrWhiteSpace(fundName))
            throw new ArgumentException("Fund name cannot be empty.", nameof(fundName));

        if (string.IsNullOrWhiteSpace(baseCurrency) || baseCurrency.Length != 3)
            throw new ArgumentException("Base currency must be a 3-letter ISO 4217 code.", nameof(baseCurrency));

        FundName = fundName.Trim();
        FundType = fundType;
        BaseCurrency = baseCurrency.Trim().ToUpperInvariant();
    }

    public void Close()
    {
        Status = FundStatus.Closed;
    }
}
