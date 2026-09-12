using BaseEntity = IFX.BuildingBlocks.Domain.BaseEntity;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Common;
using IFX.Modules.IAM.Domain.Identity;

namespace IFX.Modules.IAM.Domain.Users;

public class User : BaseEntity, IAuditableEntity
{
    public bool IsActive { get; private set; }
    public string DisplayName { get; private set; } = string.Empty;
    public Guid? PrimaryTenantId { get; private set; }
    public Guid? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private readonly List<Role> _roles = new();
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();

    private readonly List<RoleGroup> _roleGroups = new();
    public IReadOnlyCollection<RoleGroup> RoleGroups => _roleGroups.AsReadOnly();

    private readonly List<Tenant> _tenants = new();
    public IReadOnlyCollection<Tenant> Tenants => _tenants.AsReadOnly();

    private readonly List<Department> _departments = new();
    public IReadOnlyCollection<Department> Departments => _departments.AsReadOnly();

    private readonly List<UserIdentity> _identities = new();
    public IReadOnlyCollection<UserIdentity> Identities => _identities.AsReadOnly();

    private readonly List<LoginEvent> _loginEvents = new();
    public IReadOnlyCollection<LoginEvent> LoginEvents => _loginEvents.AsReadOnly();

    private readonly List<UserGlobalRole> _globalRoles = new();
    public IReadOnlyCollection<UserGlobalRole> GlobalRoles => _globalRoles.AsReadOnly();

    public bool IsGlobalAdmin =>
        _globalRoles.Any(gr => gr.GlobalRole?.Name == GlobalRoleNames.PlatformAdmin);

    private User() { } // For EF Core

    public static User Create(string displayName, bool isActive = false)
    {
        return new User
        {
            DisplayName = displayName,
            IsActive = isActive
        };
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;

    public void UpdateDisplayName(string displayName) => DisplayName = displayName;

    public void AddRole(Role role)
    {
        RequireMembership(role.TenantId);
        if (!_roles.Any(r => r.Id == role.Id))
            _roles.Add(role);
    }

    public void RemoveRole(Guid roleId)
    {
        var role = _roles.FirstOrDefault(r => r.Id == roleId);
        if (role != null)
            _roles.Remove(role);
    }

    public void AddRoleGroup(RoleGroup group)
    {
        RequireMembership(group.TenantId);
        if (group.Roles.Any(r => r.TenantId != group.TenantId)) throw new InvalidOperationException("Role group contains a cross-tenant role.");
        if (!_roleGroups.Any(g => g.Id == group.Id))
            _roleGroups.Add(group);
    }

    public void RemoveRoleGroup(Guid groupId)
    {
        var group = _roleGroups.FirstOrDefault(g => g.Id == groupId);
        if (group != null)
            _roleGroups.Remove(group);
    }

    public void AddTenant(Tenant tenant)
    {
        if (!tenant.IsActive) throw new InvalidOperationException("Tenant is inactive.");
        if (!_tenants.Any(t => t.Id == tenant.Id))
            _tenants.Add(tenant);
    }

    public void RemoveTenant(Guid tenantId)
    {
        _roles.RemoveAll(r => r.TenantId == tenantId);
        _roleGroups.RemoveAll(g => g.TenantId == tenantId);
        _departments.RemoveAll(d => d.TenantId == tenantId);
        if (PrimaryTenantId == tenantId) PrimaryTenantId = null;
        var tenant = _tenants.FirstOrDefault(t => t.Id == tenantId);
        if (tenant != null)
            _tenants.Remove(tenant);
    }

    public void SetPrimaryTenant(Guid tenantId)
    {
        RequireMembership(tenantId);
        PrimaryTenantId = tenantId;
    }

    public void ClearPrimaryTenant() => PrimaryTenantId = null;

    private void RequireMembership(Guid tenantId)
    {
        if (tenantId == Guid.Empty || !_tenants.Any(t => t.Id == tenantId && t.IsActive))
            throw new InvalidOperationException("An active tenant membership is required.");
    }

    public void AddDepartment(Department department)
    {
        RequireMembership(department.TenantId);
        if (!_departments.Any(d => d.Id == department.Id))
            _departments.Add(department);
    }

    public void RemoveDepartment(Guid departmentId)
    {
        var department = _departments.FirstOrDefault(d => d.Id == departmentId);
        if (department != null)
            _departments.Remove(department);
    }
}
