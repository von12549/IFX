using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;

namespace IFX.Modules.IAM.Domain.Tests.Entities;

public sealed class MembershipInvariantTests
{
    [Fact]
    public void No_assignment_or_primary_tenant_can_create_membership_implicitly()
    {
        var user = User.Create("User", true); var tenant = Tenant.Create("Tenant", "test");
        Assert.Throws<InvalidOperationException>(() => user.AddRole(Role.Create("Role", "test", tenant.Id)));
        Assert.Throws<InvalidOperationException>(() => user.AddRoleGroup(RoleGroup.Create("Group", "test", tenant.Id)));
        Assert.Throws<InvalidOperationException>(() => user.AddDepartment(Department.Create("Dept", "test", tenant.Id)));
        Assert.Throws<InvalidOperationException>(() => user.SetPrimaryTenant(tenant.Id));
        Assert.Throws<InvalidOperationException>(() => user.SetPrimaryTenant(Guid.Empty));
        Assert.Empty(user.Tenants); Assert.Empty(user.Roles); Assert.Empty(user.RoleGroups); Assert.Empty(user.Departments);
    }

    [Fact]
    public void Disabled_tenant_cannot_receive_new_members_or_assignments()
    {
        var user = User.Create("User", true); var tenant = Tenant.Create("Tenant", "test");
        user.AddTenant(tenant); tenant.Deactivate();
        Assert.Throws<InvalidOperationException>(() => User.Create("Other").AddTenant(tenant));
        Assert.Throws<InvalidOperationException>(() => user.AddRole(Role.Create("Role", "test", tenant.Id)));
        Assert.Throws<InvalidOperationException>(() => user.SetPrimaryTenant(tenant.Id));
        Assert.Single(user.Tenants); // Dormant facts remain auditable; access does not depend on deletion.
    }

    [Fact]
    public void Role_group_rejects_cross_tenant_roles()
    {
        var group = RoleGroup.Create("Group", "test", Guid.NewGuid());
        Assert.Throws<InvalidOperationException>(() => group.AddRole(Role.Create("Role", "test", Guid.NewGuid())));
        Assert.Empty(group.Roles);
    }
}
