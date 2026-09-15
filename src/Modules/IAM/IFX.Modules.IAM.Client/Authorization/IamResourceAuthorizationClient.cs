using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Platform.Context.Runtime;
using IFX.Platform.Context.Runtime.Outbound;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Client.Authorization;

public sealed class IamResourceAuthorizationClient(
    Contract.IResourceAuthorizationContract authorization,
    OutboundContractRequestContextFactory contextFactory)
{
    public async Task AuthorizeAsync(
        ContractComponentIdentity consumer,
        string resourceType,
        string action,
        ResourceAttributes resourceAttributes,
        IDictionary<string, object>? parameters = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(consumer);
        ArgumentNullException.ThrowIfNull(resourceAttributes);

        if (parameters is { Count: > 0 })
        {
            throw new ForbiddenException("Runtime policy parameters are not part of this contract.");
        }

        Contract.ResourceAuthorizationResponse result;
        try
        {
            var context = contextFactory.CreateTrusted(consumer);
            result = await authorization.AuthorizeAsync(
                new Contract.ResourceAuthorizationRequest(
                    resourceType,
                    action,
                    IamAuthorizationRequestMapper.Map(resourceAttributes)),
                context,
                cancellationToken);
        }
        catch (OutboundContractContextException)
        {
            throw new ForbiddenException("Missing trusted execution context.");
        }

        if (!result.Allowed)
        {
            throw new ForbiddenException("Access denied by policy.");
        }
    }
}
