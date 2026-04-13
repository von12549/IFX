namespace IFX.Modules.Registry.Application.Products.DTOs;

public class ProductDto
{
    public Guid Id { get; init; }
    public Guid TenantId { get; init; }
    public string ProductCode { get; init; } = string.Empty;
    public string ProductName { get; init; } = string.Empty;
    public string ProductType { get; init; } = string.Empty;
    public string BaseCurrency { get; init; } = string.Empty;
    public string? ApirCode { get; init; }
    public string? Isin { get; init; }
    public string? RegulatorSchemeNumber { get; init; }
    public string? PdsReference { get; init; }
    public string? IssuerName { get; init; }
    public DateOnly InceptionDate { get; init; }
    public DateOnly? WindUpDate { get; init; }
    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
