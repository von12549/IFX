using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Client.Authorization;
using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.Platform.Context.Runtime;

namespace IFX.Modules.CRM.Infrastructure.Integrations.Outbound.IAM;

public sealed class ResourceAuthorizationAdapter(IamResourceAuthorizationClient client) : IResourceAuthorizationService
{
    private static readonly ContractComponentIdentity Consumer = new("ifx", "crm", 1);

    public async Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action, TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default) where TResource : ResourceAttributes
    {
        await client.AuthorizeAsync(Consumer, resourceType, action, resourceAttributes, parameters, ct);
    }
}
