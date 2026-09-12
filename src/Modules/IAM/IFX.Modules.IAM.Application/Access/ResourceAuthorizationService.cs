using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Ports.Authorization;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Application.Access;

public sealed class ResourceAuthorizationService(ICurrentUser currentUser, IAbacPolicyResolver policies,
    IPolicyEvaluationPort evaluation, IAuthorizationEnvironmentPort environment, IExecutionContextAccessor execution)
    : IResourceAuthorizationService, Contract.IResourceAuthorizationContract
{
    public async Task AuthorizeWithResolvedPolicyAsync<TResource>(string resourceType, string action,
        TResource resourceAttributes, IDictionary<string, object>? parameters = null, CancellationToken ct = default)
        where TResource : ResourceAttributes
    {
        ct.ThrowIfCancellationRequested();
        // These mandatory constraints apply before any role exemption or provider call.
        if (!currentUser.IsAuthenticated || currentUser.UserId == Guid.Empty || !execution.HasCurrent ||
            execution.Current.Provenance != ContextProvenance.Trusted ||
            execution.Current.Actor.Kind != ActorKind.User || !Guid.TryParse(execution.Current.Actor.Id, out var actorId) || actorId != currentUser.UserId ||
            !AccessPolicySemantics.IsKnownOperation(resourceType, action))
            throw new ForbiddenException("access_context_invalid");
        var selected = new List<AbacPolicy>();
        if (execution.Current.IsTenantScope)
        {
            if (currentUser.TenantId is not { } tenantId || tenantId != execution.Current.TenantId ||
                !Guid.TryParse(resourceAttributes.TenantId, out var resourceTenant) || resourceTenant != tenantId)
                throw new ForbiddenException("access_tenant_mismatch");
            // Self-profile read has an explicit authenticated-user grant, still ANDed with ABAC and tenant constraints.
            var selfProfile = resourceType == "user" && action == "read" && resourceAttributes.OwnerId == currentUser.UserId.ToString();
            if (!selfProfile && !currentUser.Permissions.Contains(AccessPolicySemantics.Permission(resourceType, action), StringComparer.OrdinalIgnoreCase))
                throw new ForbiddenException("rbac_denied");
            var policy = await policies.ResolveTenantPolicyAsync(tenantId, resourceType, action, ct);
            if (policy is not null) selected.Add(policy);
        }
        else
        {
            // Admin is an explicit platform-scope grant. It cannot erase the mandatory context checks or a domain invariant.
            if (currentUser.IsGlobalAdmin && AccessPolicySemantics.GlobalRoleGrants("PlatformAdmin", resourceType, action)) return;
            foreach (var role in currentUser.GlobalRoles.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal))
            {
                if (!AccessPolicySemantics.GlobalRoleGrants(role, resourceType, action)) continue;
                var policy = await policies.ResolvePlatformPolicyForRoleAsync(resourceType, action, role, ct);
                if (policy is not null) selected.Add(policy);
            }
        }
        if (selected.Count == 0) throw new ForbiddenException("policy_not_configured");
        var subject = new SubjectFacts(currentUser.UserId.ToString(), currentUser.TenantId?.ToString(),
            currentUser.Departments, currentUser.Roles, currentUser.Permissions, currentUser.MfaEnabled,
            currentUser.GlobalRoles, currentUser.IsGlobalAdmin ? "true" : "false");
        var facts = environment.GetFacts();
        foreach (var policy in selected)
            if (!await evaluation.EvaluateAsync(subject, resourceAttributes, policy, facts, parameters, ct))
                throw new ForbiddenException("policy_deny");
    }

    public async Task<Contract.ResourceAuthorizationResponse> AuthorizeAsync(Contract.ResourceAuthorizationRequest request, ContractRequestContext context,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        if (context.Version != ContractRequestContext.CurrentVersion || context.SourceSystem != "ifx" || context.SourceVersion != 1 ||
            context.SourceComponent is not ("crm" or "registry" or "holdings" or "transaction") ||
            context.Provenance != ContractRequestContext.TrustedProvenance || context.ActorKind != "user" || !execution.HasCurrent ||
            execution.Current.Provenance != ContextProvenance.Trusted || context.ActorId != execution.Current.Actor.Id ||
            context.TenantId != execution.Current.TenantId ||
            context.Scope != (execution.Current.IsTenantScope ? ContractRequestContext.TenantScope : ContractRequestContext.PlatformScope))
            return new(false, "contract_context_invalid");
        if (context.Scope == ContractRequestContext.TenantScope &&
            (!Guid.TryParse(request.Resource.TenantId, out var tenant) || tenant != context.TenantId))
            return new(false, "contract_tenant_mismatch");
        try
        {
            await AuthorizeWithResolvedPolicyAsync(request.ResourceType, request.Action, new ResourceAttributes
            {
                Type = request.Resource.Type, Id = request.Resource.Id, TenantId = request.Resource.TenantId,
                IsActive = request.Resource.IsActive, OwnerId = request.Resource.OwnerId, Departments = request.Resource.Departments
            }, ct: ct);
            return new(true, "policy_allow");
        }
        catch (PolicyResolutionException ex) { return new(false, ex.Message); }
        catch (ForbiddenException) { return new(false, "policy_deny"); }
    }
}
