using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Infrastructure.Integrations.Inbound;

public sealed class ResourceAuthorizationInboundAdapter(
    IResourceAuthorizationService authorization,
    IExecutionContextAccessor execution) : Contract.IResourceAuthorizationContract
{
    public async Task<Contract.ResourceAuthorizationResponse> AuthorizeAsync(
        Contract.ResourceAuthorizationRequest request,
        ContractRequestContext context,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        if (context.Version != ContractRequestContext.CurrentVersion || context.SourceSystem != "ifx" ||
            context.SourceVersion != 1 ||
            context.SourceComponent is not ("crm" or "registry" or "holdings" or "transaction") ||
            context.Provenance != ContractRequestContext.TrustedProvenance || context.ActorKind != "user" ||
            !execution.HasCurrent || execution.Current.Provenance != ContextProvenance.Trusted ||
            context.ActorId != execution.Current.Actor.Id || context.TenantId != execution.Current.TenantId ||
            context.Scope != (execution.Current.IsTenantScope
                ? ContractRequestContext.TenantScope : ContractRequestContext.PlatformScope))
        {
            return new(false, "contract_context_invalid");
        }

        if (context.Scope == ContractRequestContext.TenantScope &&
            (!Guid.TryParse(request.Resource.TenantId, out var tenant) || tenant != context.TenantId))
        {
            return new(false, "contract_tenant_mismatch");
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
