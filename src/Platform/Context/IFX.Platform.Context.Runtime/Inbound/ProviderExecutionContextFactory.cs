using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Platform.Context.Runtime.Inbound;

public sealed class ProviderExecutionContextFactory
{
    public ExecutionContextSnapshot Create(
        ContractRequestContext context,
        ContractComponentIdentity provider)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(provider);

        var scope = context.Scope switch
        {
            ContractRequestContext.TenantScope when context.TenantId is { } tenantId
                => ExecutionScope.ForTenant(new TenantScope(tenantId)),
            ContractRequestContext.PlatformScope when context.TenantId is null
                => ExecutionScope.ForPlatform(new PlatformScope()),
            _ => throw new InvalidOperationException("A validated contract context is required.")
        };

        if (!Enum.TryParse<ActorKind>(context.ActorKind, true, out var actorKind))
        {
            throw new InvalidOperationException("A validated contract actor is required.");
        }

        return new ExecutionContextSnapshot(
            new CorrelationId(context.CorrelationId),
            OperationId.New(),
            context.CausationId is { } causationId ? new CausationId(causationId) : null,
            scope,
            new ActorReference(actorKind, context.ActorId),
            new SourceReference(provider.System, provider.Component, provider.Version));
    }
}
