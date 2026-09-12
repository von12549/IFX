namespace IFX.Modules.CRM.Application.Ports.Authorization;

public class ResourceAttributes
{
    public string Type { get; init; } = string.Empty;
    public string Id { get; init; } = string.Empty;
    public string TenantId { get; init; } = string.Empty;
    public string IsActive { get; init; } = string.Empty;
    public string? OwnerId { get; init; }
    public IReadOnlyCollection<string>? Departments { get; init; }
}

public interface IResourceAuthorizationService
{
    Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action, TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default) where TResource : ResourceAttributes;
}
