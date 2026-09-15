using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Client.Authorization;
using IFX.Modules.Transaction.Application.Ports.Authorization;
using IFX.Platform.Context.Runtime;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.IAM;

public sealed class ResourceAuthorizationAdapter(IamResourceAuthorizationClient client) : IResourceAuthorizationService
{
    public async Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action, TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default) where TResource : ResourceAttributes
    {
        await client.AuthorizeAsync(
            TransactionContractConsumer.Identity,
            resourceType,
            action,
            resourceAttributes,
            parameters,
            ct);
    }
}
