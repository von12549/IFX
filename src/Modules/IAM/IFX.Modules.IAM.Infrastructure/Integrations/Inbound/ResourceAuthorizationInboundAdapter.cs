using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Platform.Context.Contracts.Context;
using IFX.Platform.Context.Runtime;
using IFX.Platform.Context.Runtime.Inbound;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Infrastructure.Integrations.Inbound;

public sealed class ResourceAuthorizationInboundAdapter(
    IResourceAuthorizationService authorization,
    InboundContractContextValidator contextValidator) : Contract.IResourceAuthorizationContract
{
    private static readonly InboundContractPolicy Policy = new(
        [
            new ContractComponentIdentity("ifx", "crm", 1),
            new ContractComponentIdentity("ifx", "registry", 1),
            new ContractComponentIdentity("ifx", "holdings", 1),
            new ContractComponentIdentity("ifx", "transaction", 1)
        ],
        ["user"],
        allowTenantScope: true,
        allowPlatformScope: true,
        ContractTenantValidation.MatchWhenTenantScoped);

    public async Task<Contract.ResourceAuthorizationResponse> AuthorizeAsync(
        Contract.ResourceAuthorizationRequest request,
        ContractRequestContext context,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        Guid? resourceTenantId = null;
        if (context.Scope == ContractRequestContext.TenantScope &&
            Guid.TryParse(request.Resource.TenantId, out var parsedTenantId))
        {
            resourceTenantId = parsedTenantId;
        }

        var failure = contextValidator.Validate(context, resourceTenantId, Policy);
        if (failure != ContractContextFailure.None)
        {
            return new(false, failure == ContractContextFailure.TenantMismatch
                ? "contract_tenant_mismatch"
                : "contract_context_invalid");
        }

        try
        {
            await authorization.AuthorizeWithResolvedPolicyAsync(request.ResourceType, request.Action,
                new ResourceAttributes
                {
                    Type = request.Resource.Type,
                    Id = request.Resource.Id,
                    TenantId = request.Resource.TenantId,
                    IsActive = request.Resource.IsActive,
                    OwnerId = request.Resource.OwnerId,
                    Departments = request.Resource.Departments
                }, ct: ct);
            return new(true, "policy_allow");
        }
        catch (PolicyResolutionException ex) { return new(false, ex.Message); }
        catch (ForbiddenException) { return new(false, "policy_deny"); }
    }
}
