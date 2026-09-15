namespace IFX.BuildingBlocks.Security.Authorization;

public class ResourceAttributes
{
    public string Type { get; init; } = string.Empty;

    public string Id { get; init; } = string.Empty;

    public string TenantId { get; init; } = string.Empty;

    public string IsActive { get; init; } = string.Empty;

    public string? OwnerId { get; init; }

    public IReadOnlyCollection<string>? Departments { get; init; }
}
