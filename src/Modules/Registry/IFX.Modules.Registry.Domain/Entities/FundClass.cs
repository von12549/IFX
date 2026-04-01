using IFX.Modules.Registry.Domain.Common;
using IFX.Modules.Registry.Domain.Enums;

namespace IFX.Modules.Registry.Domain.Entities;

public class FundClass : BaseEntity, IAuditableEntity
{
    public Guid FundId { get; private set; }
    public Guid TenantId { get; private set; }
    public string ClassCode { get; private set; } = string.Empty;
    public string ClassName { get; private set; } = string.Empty;
    public string Currency { get; private set; } = string.Empty;
    public decimal? MinInitialInvestment { get; private set; }
    public decimal? ManagementFeeRate { get; private set; }
    public decimal? PerformanceFeeRate { get; private set; }
    public NavFrequency NavFrequency { get; private set; }
    public ClassStatus Status { get; private set; } = ClassStatus.Active;
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private FundClass() { } // For EF Core

    public static FundClass Create(
        Guid fundId,
        Guid tenantId,
        string classCode,
        string className,
        string currency,
        NavFrequency navFrequency)
    {
        if (fundId == Guid.Empty)
            throw new ArgumentException("FundId must be provided.", nameof(fundId));

        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        if (string.IsNullOrWhiteSpace(classCode))
            throw new ArgumentException("Class code cannot be empty.", nameof(classCode));

        if (string.IsNullOrWhiteSpace(className))
            throw new ArgumentException("Class name cannot be empty.", nameof(className));

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
            throw new ArgumentException("Currency must be a 3-letter ISO 4217 code.", nameof(currency));

        return new FundClass
        {
            FundId = fundId,
            TenantId = tenantId,
            ClassCode = classCode.Trim().ToUpperInvariant(),
            ClassName = className.Trim(),
            Currency = currency.Trim().ToUpperInvariant(),
            NavFrequency = navFrequency,
            Status = ClassStatus.Active
        };
    }

    public void Update(
        string className,
        string currency,
        decimal? minInitialInvestment,
        decimal? managementFeeRate,
        decimal? performanceFeeRate,
        NavFrequency navFrequency)
    {
        if (string.IsNullOrWhiteSpace(className))
            throw new ArgumentException("Class name cannot be empty.", nameof(className));

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
            throw new ArgumentException("Currency must be a 3-letter ISO 4217 code.", nameof(currency));

        ClassName = className.Trim();
        Currency = currency.Trim().ToUpperInvariant();
        MinInitialInvestment = minInitialInvestment;
        ManagementFeeRate = managementFeeRate;
        PerformanceFeeRate = performanceFeeRate;
        NavFrequency = navFrequency;
    }

    public void Close()
    {
        Status = ClassStatus.Closed;
    }

    public bool IsOpenForSubscription()
    {
        return Status == ClassStatus.Active;
    }
}
