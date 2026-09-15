using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Platform.Context.Runtime.Inbound;

public sealed class InboundContractContextValidator(IExecutionContextAccessor executionContext)
{
    public ContractContextFailure Validate(
        ContractRequestContext context,
        Guid? resourceTenantId,
        InboundContractPolicy policy)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(policy);

        var consumer = new ContractComponentIdentity(
            context.SourceSystem,
            context.SourceComponent,
            context.SourceVersion);
        if (!policy.AllowsConsumer(consumer))
        {
            return ContractContextFailure.ConsumerDenied;
        }

        var tenantScope = context.Scope == ContractRequestContext.TenantScope;
        var platformScope = context.Scope == ContractRequestContext.PlatformScope;
        if (context.Version != ContractRequestContext.CurrentVersion ||
            tenantScope && !policy.AllowTenantScope ||
            platformScope && !policy.AllowPlatformScope ||
            !tenantScope && !platformScope)
        {
            return ContractContextFailure.ContextInvalid;
        }

        if (context.Provenance != ContractRequestContext.TrustedProvenance ||
            !policy.AllowsActor(context.ActorKind) ||
            !executionContext.HasCurrent ||
            executionContext.Current.Provenance != ContextProvenance.Trusted ||
            context.ActorKind != executionContext.Current.Actor.Kind.ToString().ToLowerInvariant() ||
            context.ActorId != executionContext.Current.Actor.Id ||
            context.Scope != (executionContext.Current.IsTenantScope
                ? ContractRequestContext.TenantScope
                : ContractRequestContext.PlatformScope) ||
            context.TenantId != executionContext.Current.TenantId)
        {
            return ContractContextFailure.ContextInvalid;
        }

        var resourceTenantInvalid = resourceTenantId is not { } tenantId || tenantId == Guid.Empty;
        return policy.TenantValidation switch
        {
            ContractTenantValidation.RequireTenantResource
                when resourceTenantInvalid || !tenantScope || context.TenantId != resourceTenantId
                => ContractContextFailure.TenantMismatch,
            ContractTenantValidation.MatchWhenTenantScoped
                when tenantScope && (resourceTenantInvalid || context.TenantId != resourceTenantId)
                => ContractContextFailure.TenantMismatch,
            _ => ContractContextFailure.None
        };
    }
}
