using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Access;

/// <summary>IAM facts are loaded from committed storage, never from caller role/tenant claims.</summary>
public sealed class VerifiedIdentityFacts(HttpIdentityFacts identity, ExecutionTenantSelection selection, IfxDbContext db) : IExecutionIdentityFacts
{
    private User? _snapshot;
    private bool _loaded;
    private User? Snapshot => _loaded ? _snapshot : Refresh();

    // Each authorization gate starts with this check and refreshes the complete subject snapshot.
    public bool IsAuthenticated => identity.IsAuthenticated && Refresh() is { IsActive: true };
    public Guid UserId => identity.UserId;
    public bool MfaEnabled => identity.MfaEnabled;
    public Guid? TenantId => selection.ResolveTenantId() is { } tenant && IsSnapshotMember(tenant) ? tenant : null;
    public Guid? PrimaryTenantId => Snapshot?.PrimaryTenantId is { } tenant && IsSnapshotMember(tenant) ? tenant : null;
    public IReadOnlyCollection<string> Departments => TenantId is { } tenant
        ? Snapshot!.Departments.Where(d => d.TenantId == tenant).Select(d => d.Name).Distinct().ToArray() : [];
    public IReadOnlyCollection<string> Roles => ScopedRoles().Select(r => r.Name).Distinct().ToArray();
    public IReadOnlyCollection<string> Permissions => ScopedRoles().SelectMany(r => r.Permissions).Select(p => p.Name).Distinct().ToArray();
    public IReadOnlyList<string> GlobalRoles => Snapshot is { IsActive: true } user
        ? user.GlobalRoles.Where(r => r.GlobalRole is not null).Select(r => r.GlobalRole.Name).Distinct().Order().ToArray() : [];

    public bool IsTenantMember(Guid tenantId) => identity.IsAuthenticated && identity.UserId != Guid.Empty &&
        db.Users.AsNoTracking().Any(u => u.Id == identity.UserId && u.IsActive && u.Tenants.Any(t => t.Id == tenantId && t.IsActive));

    private bool IsSnapshotMember(Guid tenantId) => Snapshot is { IsActive: true } user && user.Tenants.Any(t => t.Id == tenantId && t.IsActive);
    private IEnumerable<Role> ScopedRoles()
    {
        if (TenantId is not { } tenant) return [];
        var user = Snapshot!;
        return user.Roles.Where(r => r.TenantId == tenant).Concat(user.RoleGroups.Where(g => g.TenantId == tenant)
            .SelectMany(g => g.Roles).Where(r => r.TenantId == tenant));
    }
    private User? Refresh()
    {
        _loaded = true;
        if (!identity.IsAuthenticated || identity.UserId == Guid.Empty) return _snapshot = null;
        return _snapshot = db.Users.AsNoTracking()
            .Include(u => u.Tenants).Include(u => u.Departments)
            .Include(u => u.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.RoleGroups).ThenInclude(g => g.Roles).ThenInclude(r => r.Permissions)
            .Include(u => u.GlobalRoles).ThenInclude(g => g.GlobalRole)
            .SingleOrDefault(u => u.Id == identity.UserId);
    }
}
