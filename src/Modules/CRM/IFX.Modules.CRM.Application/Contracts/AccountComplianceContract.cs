using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.CRM.Application.Contracts;

public sealed class AccountComplianceContract(
    IAccountComplianceDataPort dataPort,
    IExecutionContextScopeFactory scopeFactory) : IAccountComplianceContract
{
    public const string ConsumerDenied = "contract_consumer_denied";
    public const string ContextInvalid = "contract_context_invalid";
    public const string TenantMismatch = "contract_tenant_mismatch";
    public const string Unavailable = "contract_unavailable";

    public async Task<AccountComplianceResponse> CheckAsync(
        AccountComplianceRequest request,
        ContractRequestContext context,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Validate(context, request.TenantId);

        var child = CreateChildContext(context);
        try
        {
            using var scope = scopeFactory.Push(child);
            var approved = await dataPort.IsInvestmentAccountKycApprovedAsync(
                request.InvestmentAccountId,
                request.TenantId,
                cancellationToken);
            return new AccountComplianceResponse(approved);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (AccountComplianceContractException)
        {
            throw;
        }
        catch (Exception)
        {
            throw new AccountComplianceContractException(Unavailable);
        }
    }

    private static void Validate(ContractRequestContext context, Guid resourceTenantId)
    {
        if (context.SourceSystem != "ifx" || context.SourceComponent != "transaction" || context.SourceVersion != 1)
        {
            throw new AccountComplianceContractException(ConsumerDenied);
        }

        if (context.Version != ContractRequestContext.CurrentVersion ||
            context.Scope is not (ContractRequestContext.TenantScope or ContractRequestContext.PlatformScope))
        {
            throw new AccountComplianceContractException(ContextInvalid);
        }

        if (context.Provenance != ContractRequestContext.TrustedProvenance ||
            context.ActorKind is not ("user" or "service" or "system"))
        {
            throw new AccountComplianceContractException(ContextInvalid);
        }

        if (resourceTenantId == Guid.Empty ||
            context.Scope != ContractRequestContext.TenantScope ||
            context.TenantId != resourceTenantId)
        {
            throw new AccountComplianceContractException(TenantMismatch);
        }
    }

    private static ExecutionContextSnapshot CreateChildContext(ContractRequestContext context) => new(
        new CorrelationId(context.CorrelationId),
        OperationId.New(),
        context.CausationId is { } causationId ? new CausationId(causationId) : null,
        ExecutionScope.ForTenant(new TenantScope(context.TenantId!.Value)),
        new ActorReference(Enum.Parse<ActorKind>(context.ActorKind, true), context.ActorId),
        new SourceReference("ifx", "crm-provider", 1));
}
