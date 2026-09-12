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
        // Baseline role semantics are owned by IAM; Phase 4 changes these explicitly.
        if (currentUser.IsGlobalAdmin) return;
        AbacPolicy? policy = currentUser.GlobalRoles.Count > 0
            ? await policies.ResolvePlatformPolicyForRoleAsync(resourceType, action, currentUser.GlobalRoles[0], ct)
            : currentUser.TenantId.HasValue
                ? await policies.ResolveTenantPolicyAsync(currentUser.TenantId.Value, resourceType, action, ct)
                : null;
        if (policy is null) throw new ForbiddenException($"No ABAC policy defined for '{resourceType}/{action}'.");
        var subject = new SubjectFacts(currentUser.UserId.ToString(), currentUser.TenantId?.ToString(),
            currentUser.Departments, currentUser.Roles, currentUser.Permissions, currentUser.MfaEnabled,
            currentUser.GlobalRoles, currentUser.IsGlobalAdmin ? "true" : "false");
        if (!await evaluation.EvaluateAsync(subject, resourceAttributes, policy, environment.GetFacts(), parameters, ct))
            throw new ForbiddenException("Access denied by policy.");
    }

    public async Task<Contract.ResourceAuthorizationResponse> AuthorizeAsync(Contract.ResourceAuthorizationRequest request, ContractRequestContext context,
        CancellationToken ct = default)
    {
        ct.ThrowIfCancellationRequested();
        if (context.Version != ContractRequestContext.CurrentVersion || context.SourceSystem != "ifx" || context.SourceVersion != 1 ||
            context.SourceComponent is not ("crm" or "registry" or "holdings" or "transaction") ||
            context.Provenance != ContractRequestContext.TrustedProvenance || !execution.HasCurrent ||
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
        catch (ForbiddenException) { return new(false, "policy_deny"); }
    }
}
