using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Domain.Access;

namespace IFX.Modules.IAM.Infrastructure.Access;

/// <summary>Reads committed policies per evaluation. No cross-request cache or outage fallback.</summary>
public sealed class DbAbacPolicyResolver(
    IPolicyDefinitionRepository repository, IAbacTemplateRegistry templates, StaticAbacPolicyResolver defaults) : IAbacPolicyResolver, IAbacPolicyCache
{
    public void RegisterDefault(string resourceType, string action, AbacPolicy policy) => defaults.RegisterDefault(resourceType, action, policy);

    public async Task<AbacPolicy?> ResolveTenantPolicyAsync(Guid tenantId, string resourceType, string action, CancellationToken ct = default)
    {
        var row = await Read(() => repository.GetAsync(tenantId, resourceType, action, ct), ct);
        if (row is not null) return Parse(row, resourceType, action);
        return await ResolvePlatformPolicyAsync(resourceType, action, ct);
    }

    public async Task<AbacPolicy?> ResolvePlatformPolicyAsync(string resourceType, string action, CancellationToken ct = default)
    {
        var row = await Read(() => repository.GetPlatformAsync(resourceType, action, ct), ct);
        // Only a successfully observed absence may select a registered code default.
        return row is null ? await defaults.ResolvePlatformPolicyAsync(resourceType, action, ct) : Parse(row, resourceType, action);
    }

    public async Task<AbacPolicy?> ResolvePlatformPolicyForRoleAsync(string resourceType, string action, string globalRole, CancellationToken ct = default)
    {
        var row = await Read(() => repository.GetPlatformByGlobalRoleAsync(resourceType, action, globalRole, ct), ct);
        return row is null ? null : Parse(row, resourceType, action);
    }

    private static async Task<PolicyDefinition?> Read(Func<Task<PolicyDefinition?>> read, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        try { return await read(); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (JsonException) { throw new PolicyResolutionException(PolicyFailure.Invalid); }
        catch (InvalidDataException) { throw new PolicyResolutionException(PolicyFailure.Invalid); }
        catch (Exception) { throw new PolicyResolutionException(PolicyFailure.Unavailable); }
    }

    private AbacPolicy Parse(PolicyDefinition row, string resourceType, string action)
    {
        if (!row.IsActive) throw new PolicyResolutionException(PolicyFailure.Disabled);
        try
        {
            var records = JsonSerializer.Deserialize<List<PolicyConditionRecord>>(row.ConditionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (records is null || records.Count is 0 or > 100 || records.Any(r => r is null || !templates.TryResolve(r.TemplateName, out _)))
                throw new PolicyResolutionException(PolicyFailure.Invalid);
            var conditions = records.Select(r => new AbacCondition
            {
                Template = templates.Resolve(r.TemplateName),
                Parameters = r.Parameters?.ToDictionary(kv => kv.Key, kv => (object)kv.Value)
            }).ToArray();
            if (conditions.Any(c => c.Template.Right.Type == Application.Access.Abac.Templates.ValueRefType.UserInput &&
                (c.Parameters is null || !c.Parameters.ContainsKey(c.Template.Right.Value))))
                throw new PolicyResolutionException(PolicyFailure.Invalid);
            // Tenant policy cannot reference a platform privilege template, even if inserted outside the API.
            if (row.Scope == PolicyScope.Tenant && records.Any(r => r.TemplateName is "AnyTenant" or "GlobalRoleIncludes"))
                throw new PolicyResolutionException(PolicyFailure.Invalid);
            return new AbacPolicy
            {
                ResourceType = resourceType.ToLowerInvariant(), Action = action.ToLowerInvariant(), Conditions = conditions,
                Version = "iam-v2:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(row.Id + ":" + row.Scope + ":" + row.ConditionsJson))),
                Classification = row.Scope == PolicyScope.Tenant ? "tenant-custom" : records.Any(r => r.TemplateName == "GlobalRoleIncludes") ? "platform-role-grant" : "overridable-default"
            };
        }
        catch (PolicyResolutionException) { throw; }
        catch (Exception) { throw new PolicyResolutionException(PolicyFailure.Invalid); }
    }

    // Retained for existing management use cases; no cache exists to invalidate on any instance.
    public void Invalidate(Guid tenantId, string resourceType, string action) { }
    public void InvalidatePlatform(string resourceType, string action) { }
}
