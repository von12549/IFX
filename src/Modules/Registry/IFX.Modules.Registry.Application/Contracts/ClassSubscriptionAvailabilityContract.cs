using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.Ports;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.Registry.Application.Contracts;

public sealed class ClassSubscriptionAvailabilityContract(
    IClassSubscriptionDataPort dataPort,
    IExecutionContextScopeFactory scopeFactory) : IClassSubscriptionAvailabilityContract
{
    public const string ConsumerDenied = "contract_consumer_denied";
    public const string ContextInvalid = "contract_context_invalid";
    public const string TenantMismatch = "contract_tenant_mismatch";
    public const string Unavailable = "contract_unavailable";

    public async Task<ClassSubscriptionAvailabilityResponse> CheckAsync(
        ClassSubscriptionAvailabilityRequest request,
        ContractRequestContext context,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Validate(context, request.TenantId);

        var child = CreateChildContext(context);
        try
        {
            using var scope = scopeFactory.Push(child);
            var isOpen = await dataPort.IsClassOpenForSubscriptionAsync(
                request.ClassId,
                request.TenantId,
                cancellationToken);
            return new ClassSubscriptionAvailabilityResponse(isOpen);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (ClassSubscriptionAvailabilityContractException)
        {
            throw;
        }
        catch (Exception)
        {
            throw new ClassSubscriptionAvailabilityContractException(Unavailable);
        }
    }

    private static void Validate(ContractRequestContext context, Guid resourceTenantId)
    {
        if (context.SourceSystem != "ifx" || context.SourceComponent != "transaction" || context.SourceVersion != 1)
        {
            throw new ClassSubscriptionAvailabilityContractException(ConsumerDenied);
        }

        if (context.Version != ContractRequestContext.CurrentVersion ||
            context.Scope is not (ContractRequestContext.TenantScope or ContractRequestContext.PlatformScope))
        {
            throw new ClassSubscriptionAvailabilityContractException(ContextInvalid);
        }

        if (context.Provenance != ContractRequestContext.TrustedProvenance ||
            context.ActorKind is not ("user" or "service" or "system"))
        {
            throw new ClassSubscriptionAvailabilityContractException(ContextInvalid);
        }

        if (resourceTenantId == Guid.Empty ||
            context.Scope != ContractRequestContext.TenantScope ||
            context.TenantId != resourceTenantId)
        {
            throw new ClassSubscriptionAvailabilityContractException(TenantMismatch);
        }
    }

    private static ExecutionContextSnapshot CreateChildContext(ContractRequestContext context) => new(
        new CorrelationId(context.CorrelationId),
        OperationId.New(),
        context.CausationId is { } causationId ? new CausationId(causationId) : null,
        ExecutionScope.ForTenant(new TenantScope(context.TenantId!.Value)),
        new ActorReference(Enum.Parse<ActorKind>(context.ActorKind, true), context.ActorId),
        new SourceReference("ifx", "registry-provider", 1));
}
