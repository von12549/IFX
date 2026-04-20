namespace IFX.Modules.Registry.Application.Funds.DTOs;

public class FundDto
{
    public Guid Id { get; init; }
    public Guid TenantId { get; init; }
    public Guid? ProductId { get; init; }
    public string FundCode { get; init; } = string.Empty;
    public string FundName { get; init; } = string.Empty;
    public string FundType { get; init; } = string.Empty;
    public string BaseCurrency { get; init; } = string.Empty;
    public DateOnly InceptionDate { get; init; }
    public string Status { get; init; } = string.Empty;
    public DateTimeOffset CreatedAt { get; init; }
    public DateTimeOffset UpdatedAt { get; init; }
}
