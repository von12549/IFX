using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.ClassSubscriptionAvailability;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Platform.Context.Contracts.Context;
using IFX.Platform.Context.Runtime;
using IFX.Platform.Context.Runtime.Inbound;

namespace IFX.Modules.Registry.Infrastructure.Integrations.Inbound;

public sealed class ClassSubscriptionAvailabilityInboundAdapter(
    IClassSubscriptionAvailabilityUseCase useCase,
    IExecutionContextScopeFactory scopeFactory,
    InboundContractContextValidator contextValidator,
    ProviderExecutionContextFactory contextFactory) : IClassSubscriptionAvailabilityContract
{
    private static readonly InboundContractPolicy Policy = new(
        [new ContractComponentIdentity("ifx", "transaction", 1)],
        ["user", "service", "system"],
        allowTenantScope: true,
        allowPlatformScope: true,
        ContractTenantValidation.RequireTenantResource);

    private static readonly ContractComponentIdentity Provider = new("ifx", "registry-provider", 1);

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
        ThrowForFailure(contextValidator.Validate(context, request.TenantId, Policy));

        var child = contextFactory.Create(context, Provider);
        try
        {
            using var scope = scopeFactory.Push(child);
            var isOpen = await useCase.IsOpenAsync(request.ClassId, request.TenantId, cancellationToken);
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

    private static void ThrowForFailure(ContractContextFailure failure)
    {
        var code = failure switch
        {
            ContractContextFailure.None => null,
            ContractContextFailure.ConsumerDenied => ConsumerDenied,
            ContractContextFailure.TenantMismatch => TenantMismatch,
            _ => ContextInvalid
        };
        if (code is not null)
        {
            throw new ClassSubscriptionAvailabilityContractException(code);
        }
    }
}
