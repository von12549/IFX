using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Access;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.IAM.Infrastructure.Persistence;

// Validate the persisted result before commit, including DeferredWrite callers. Serializable reads prevent
// a concurrent membership exit and grant from committing an orphan relation. Existing anomalies are never
// repaired by inventing memberships; they remain visible to the read-only rollout audit.
internal sealed class MembershipPersistenceValidation
{
    private readonly HashSet<Guid> _users = [];
    private readonly HashSet<Guid> _groups = [];
    private readonly HashSet<Guid> _addedRoles = [];
    private readonly HashSet<Guid> _addedGroups = [];
    private readonly HashSet<Guid> _addedDepartments = [];
    private readonly HashSet<Guid> _addedTenants = [];

    public static MembershipPersistenceValidation Capture(IfxDbContext db)
    {
        db.ChangeTracker.DetectChanges();
        var changes = new MembershipPersistenceValidation();
        foreach (var entry in db.ChangeTracker.Entries().Where(e => e.State is EntityState.Added or EntityState.Modified or EntityState.Deleted))
        {
            if (entry.Entity is User user) changes._users.Add(user.Id);
            if (entry.Entity is RoleGroup group) changes._groups.Add(group.Id);
            if (entry.Metadata.GetTableName() is not ("UserRoles" or "UserRoleGroups" or "UserDepartments" or "UserTenants" or "RoleGroupRoles")) continue;
            foreach (var foreignKey in entry.Metadata.GetForeignKeys())
            {
                if (foreignKey.Properties.Count != 1 || entry.Property(foreignKey.Properties[0].Name).CurrentValue is not Guid id) continue;
                var principal = foreignKey.PrincipalEntityType.ClrType;
                if (principal == typeof(User)) changes._users.Add(id);
                if (principal == typeof(RoleGroup)) changes._groups.Add(id);
                if (entry.State != EntityState.Added) continue;
                if (principal == typeof(Role)) changes._addedRoles.Add(id);
                if (principal == typeof(RoleGroup)) changes._addedGroups.Add(id);
                if (principal == typeof(Department)) changes._addedDepartments.Add(id);
                if (principal == typeof(Tenant)) changes._addedTenants.Add(id);
            }
        }
        return changes;
    }

    public async Task ValidateAsync(IfxDbContext db, CancellationToken ct)
    {
        if (_users.Count > 0 && await db.Users.AsNoTracking().Where(u => _users.Contains(u.Id)).AnyAsync(u =>
            u.Roles.Any(r => !u.Tenants.Any(t => t.Id == r.TenantId)) ||
            u.RoleGroups.Any(g => !u.Tenants.Any(t => t.Id == g.TenantId)) ||
            u.Departments.Any(d => !u.Tenants.Any(t => t.Id == d.TenantId)) ||
            u.PrimaryTenantId.HasValue && !u.Tenants.Any(t => t.Id == u.PrimaryTenantId), ct))
            throw new InvalidOperationException("iam_membership_relation_invalid");
        if (_groups.Count > 0 && await db.RoleGroups.AsNoTracking().Where(g => _groups.Contains(g.Id))
            .AnyAsync(g => g.Roles.Any(r => r.TenantId != g.TenantId), ct))
            throw new InvalidOperationException("iam_role_group_tenant_mismatch");
        if (_addedRoles.Count > 0 && await db.Roles.AnyAsync(r => _addedRoles.Contains(r.Id) && !r.Tenant.IsActive, ct) ||
            _addedGroups.Count > 0 && await db.RoleGroups.AnyAsync(g => _addedGroups.Contains(g.Id) && !g.Tenant.IsActive, ct) ||
            _addedDepartments.Count > 0 && await db.Departments.AnyAsync(d => _addedDepartments.Contains(d.Id) && !d.Tenant.IsActive, ct) ||
            _addedTenants.Count > 0 && await db.Tenants.AnyAsync(t => _addedTenants.Contains(t.Id) && !t.IsActive, ct))
            throw new InvalidOperationException("iam_tenant_inactive");
    }
}
