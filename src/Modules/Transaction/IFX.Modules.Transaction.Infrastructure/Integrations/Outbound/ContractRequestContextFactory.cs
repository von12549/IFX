using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.Transaction.Infrastructure.Integrations.Outbound;

internal static class ContractRequestContextFactory
{
    public static ContractRequestContext Create(IExecutionContextAccessor accessor, Guid resourceTenantId)
    {
        if (!accessor.HasCurrent)
        {
            throw new InvalidOperationException("contract_context_invalid");
        }

        var current = accessor.Current;
        if (!current.IsTenantScope || current.TenantId != resourceTenantId)
        {
            throw new InvalidOperationException("contract_tenant_mismatch");
        }

        return new ContractRequestContext(
            Guid.NewGuid(),
            current.CorrelationId.Value,
            current.OperationId.Value,
            ContractRequestContext.TenantScope,
            current.TenantId,
            current.Actor.Kind.ToString().ToLowerInvariant(),
            current.Actor.Id,
            "ifx",
            "transaction",
            1,
            current.Provenance == ContextProvenance.Trusted
                ? ContractRequestContext.TrustedProvenance
                : ContractRequestContext.SynthesizedProvenance);
    }
}
