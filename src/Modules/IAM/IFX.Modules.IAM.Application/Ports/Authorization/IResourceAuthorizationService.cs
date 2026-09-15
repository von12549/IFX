using IFX.BuildingBlocks.Security.Authorization;

namespace IFX.Modules.IAM.Application.Ports.Authorization;

public interface IResourceAuthorizationService
{
    Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action, TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default) where TResource : ResourceAttributes;
}
