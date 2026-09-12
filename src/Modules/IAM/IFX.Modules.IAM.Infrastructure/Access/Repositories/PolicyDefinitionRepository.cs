using System.Text.Json;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.BuildingBlocks.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Access.Repositories;

public class PolicyDefinitionRepository : IPolicyDefinitionRepository
{
    private readonly IfxDbContext _context;

    public PolicyDefinitionRepository(IfxDbContext context)
    {
        _context = context;
    }

    public async Task<PolicyDefinition?> GetAsync(
        Guid tenantId, string resourceType, string action, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PolicyDefinitions.AsNoTracking()
            .FirstOrDefaultAsync(
                p => p.Scope == PolicyScope.Tenant
                  && p.TenantId == tenantId
                  && p.ResourceType == resourceType.ToLowerInvariant()
                  && p.Action == action.ToLowerInvariant(),
                ct);
    }

    public async Task<List<PolicyDefinition>> GetByTenantIdAsync(
        Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PolicyDefinitions
            .AsNoTracking()
            .Where(p => p.Scope == PolicyScope.Tenant && p.TenantId == tenantId && p.IsActive)
            .ToListAsync(ct);
    }

    public async Task AddAsync(PolicyDefinition policy, CancellationToken ct = default)
        => await _context.PolicyDefinitions.AddAsync(policy, ct);

    public void Remove(PolicyDefinition policy)
        => _context.PolicyDefinitions.Remove(policy);

    public async Task<bool> ExistsAsync(
        Guid tenantId, string resourceType, string action, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PolicyDefinitions
            .AnyAsync(
                p => p.Scope == PolicyScope.Tenant
                  && p.TenantId == tenantId
                  && p.ResourceType == resourceType.ToLowerInvariant()
                  && p.Action == action.ToLowerInvariant(),
                ct);
    }

    public async Task<PolicyDefinition?> GetTenantByIdAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        TenantQueryGuard.Require(tenantId);
        return await _context.PolicyDefinitions.FirstOrDefaultAsync(
            p => p.Id == id && p.Scope == PolicyScope.Tenant && p.TenantId == tenantId,
            ct);
    }

    public async Task<PolicyDefinition?> GetPlatformByIdAsync(Guid id, CancellationToken ct = default)
        => await _context.PolicyDefinitions.FirstOrDefaultAsync(
            p => p.Id == id && p.Scope == PolicyScope.Platform && p.TenantId == null,
            ct);

    public async Task<PolicyDefinition?> GetPlatformAsync(string resourceType, string action, CancellationToken ct = default)
        => Select(await Candidates(resourceType, action, ct), null);

    public async Task<PolicyDefinition?> GetPlatformByGlobalRoleAsync(string resourceType, string action, string globalRole, CancellationToken ct = default)
        => Select(await Candidates(resourceType, action, ct), globalRole);

    private Task<List<PolicyDefinition>> Candidates(string resourceType, string action, CancellationToken ct) =>
        _context.PolicyDefinitions.AsNoTracking().Where(p => p.Scope == PolicyScope.Platform && p.TenantId == null &&
            p.ResourceType == resourceType.ToLowerInvariant() && p.Action == action.ToLowerInvariant()).ToListAsync(ct);

    private static PolicyDefinition? Select(List<PolicyDefinition> candidates, string? role)
    {
        var selected = new List<PolicyDefinition>();
        foreach (var candidate in candidates)
        {
            var records = JsonSerializer.Deserialize<List<PolicyConditionRecord>>(candidate.ConditionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new InvalidDataException("Invalid policy conditions.");
            if (records.Count == 0 || records.Any(r => r is null)) throw new InvalidDataException("Invalid policy conditions.");
            var roleConditions = records.Where(r => r.TemplateName == "GlobalRoleIncludes").ToArray();
            if (roleConditions.Any(r => r.Parameters is null || !r.Parameters.ContainsKey("global_role")))
                throw new InvalidDataException("Missing role selector.");
            if (role is null ? roleConditions.Length == 0 : roleConditions.Any(r =>
                r.Parameters is not null && r.Parameters.TryGetValue("global_role", out var value) && value?.ToString() == role)) selected.Add(candidate);
        }
        if (selected.Count > 1) throw new InvalidDataException("Ambiguous policy selection.");
        return selected.SingleOrDefault();
    }

    public Task<List<PolicyDefinition>> GetPlatformPoliciesAsync(CancellationToken ct = default)
        => _context.PolicyDefinitions
            .AsNoTracking()
            .Where(p => p.Scope == PolicyScope.Platform && p.IsActive)
            .ToListAsync(ct);

    public Task<bool> ExistsPlatformAsync(
        string resourceType, string action, CancellationToken ct = default)
        => _context.PolicyDefinitions
            .AnyAsync(
                p => p.Scope == PolicyScope.Platform
                  && p.ResourceType == resourceType.ToLowerInvariant()
                  && p.Action == action.ToLowerInvariant(),
                ct);
}
