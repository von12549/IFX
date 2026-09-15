using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Platform.Context.Runtime.Outbound;

public sealed class OutboundContractRequestContextFactory(IExecutionContextAccessor executionContext)
{
    public ContractRequestContext CreateTrusted(ContractComponentIdentity consumer)
    {
        var current = RequireCurrent();
        if (current.Provenance != ContextProvenance.Trusted)
        {
            throw new OutboundContractContextException(OutboundContractContextFailure.ContextInvalid);
        }

        return Create(current, consumer, ContractRequestContext.TrustedProvenance);
    }

    public ContractRequestContext CreateTenantCall(
        Guid resourceTenantId,
        ContractComponentIdentity consumer)
    {
        var current = RequireCurrent();
        if (resourceTenantId == Guid.Empty || !current.IsTenantScope || current.TenantId != resourceTenantId)
        {
            throw new OutboundContractContextException(OutboundContractContextFailure.TenantMismatch);
        }

        return Create(
            current,
            consumer,
            current.Provenance == ContextProvenance.Trusted
                ? ContractRequestContext.TrustedProvenance
                : ContractRequestContext.SynthesizedProvenance);
    }

    private ExecutionContextSnapshot RequireCurrent()
    {
        if (!executionContext.HasCurrent)
        {
            throw new OutboundContractContextException(OutboundContractContextFailure.ContextInvalid);
        }

        return executionContext.Current;
    }

    private static ContractRequestContext Create(
        ExecutionContextSnapshot current,
        ContractComponentIdentity consumer,
        string provenance)
    {
        ArgumentNullException.ThrowIfNull(consumer);

        return new ContractRequestContext(
            Guid.NewGuid(),
            current.CorrelationId.Value,
            current.OperationId.Value,
            current.IsTenantScope ? ContractRequestContext.TenantScope : ContractRequestContext.PlatformScope,
            current.TenantId,
            current.Actor.Kind.ToString().ToLowerInvariant(),
            current.Actor.Id,
            consumer.System,
            consumer.Component,
            consumer.Version,
            provenance);
    }
}
