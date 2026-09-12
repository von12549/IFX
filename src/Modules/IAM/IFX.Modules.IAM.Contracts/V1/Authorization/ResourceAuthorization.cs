using IFX.Platform.Context.Contracts.Context;
namespace IFX.Modules.IAM.Contracts.V1.Authorization;

public sealed record ResourceAttributes
{
    public string Type { get; init; } = string.Empty;
    public string Id { get; init; } = string.Empty;
    public string TenantId { get; init; } = string.Empty;
    public string IsActive { get; init; } = string.Empty;
    public string? OwnerId { get; init; }
    public IReadOnlyCollection<string>? Departments { get; init; }
}

public sealed record ResourceAuthorizationRequest(string ResourceType, string Action, ResourceAttributes Resource);
public sealed record ResourceAuthorizationResponse(bool Allowed, string ReasonCode);
