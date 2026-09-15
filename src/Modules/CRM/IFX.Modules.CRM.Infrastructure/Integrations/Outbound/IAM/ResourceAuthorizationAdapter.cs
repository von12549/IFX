using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;
using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.CRM.Infrastructure.Integrations.Outbound.IAM;

public sealed class ResourceAuthorizationAdapter(Contract.IResourceAuthorizationContract authorization, IExecutionContextAccessor execution) : IResourceAuthorizationService
{
    public async Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action, TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default) where TResource : ResourceAttributes
    {
        if (parameters is { Count: > 0 }) throw new ForbiddenException("Runtime policy parameters are not part of this contract.");
        if (!execution.HasCurrent || execution.Current.Provenance != ContextProvenance.Trusted) throw new ForbiddenException("Missing trusted execution context.");
        var current = execution.Current;
        var context = new ContractRequestContext(Guid.NewGuid(), current.CorrelationId.Value, current.OperationId.Value,
            current.IsTenantScope ? ContractRequestContext.TenantScope : ContractRequestContext.PlatformScope,
            current.TenantId, current.Actor.Kind.ToString().ToLowerInvariant(), current.Actor.Id, "ifx", "crm", 1,
            ContractRequestContext.TrustedProvenance);
        var result = await authorization.AuthorizeAsync(new Contract.ResourceAuthorizationRequest(resourceType, action, new Contract.ResourceAttributes
        {
            Type = resourceAttributes.Type, Id = resourceAttributes.Id, TenantId = resourceAttributes.TenantId,
            IsActive = resourceAttributes.IsActive, OwnerId = resourceAttributes.OwnerId, Departments = resourceAttributes.Departments
        }), context, ct);
        if (!result.Allowed) throw new ForbiddenException("Access denied by policy.");
    }
}
