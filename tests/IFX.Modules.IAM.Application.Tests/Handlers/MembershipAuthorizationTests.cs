using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Tenancy.Membership.Commands.AssignTenantToUser;
using IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveTenantFromUser;
using IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveDepartmentFromUser;
using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.Extensions.Logging.Abstractions;

namespace IFX.Modules.IAM.Application.Tests.Handlers;

public sealed class MembershipAuthorizationTests
{
    [Fact]
    public async Task Department_removal_cannot_target_another_membership_of_the_same_user()
    {
        var tenant = Tenant.Create("Other tenant", "test");
        var target = User.Create("Target", true); target.AddTenant(tenant);
        var department = Department.Create("Other department", "test", tenant.Id); target.AddDepartment(department);
        var current = new Mock<ICurrentUser>(); current.SetupGet(u => u.IsAuthenticated).Returns(true);
        current.SetupGet(u => u.TenantId).Returns(Guid.NewGuid());
        var permission = new Mock<IPermissionChecker>(); permission.Setup(p => p.HasPermissionAsync("User:update", default)).ReturnsAsync(true);
        var work = new Mock<IUnitOfWork> { DefaultValue = DefaultValue.Mock };
        work.Setup(w => w.Users.GetByIdWithTenantsAndDepartmentsAsync(target.Id, default)).ReturnsAsync(target);
        var handler = new RemoveDepartmentFromUserCommandHandler(work.Object, NullLogger<RemoveDepartmentFromUserCommandHandler>.Instance, permission.Object, current.Object);
        Assert.False((await handler.Handle(new(target.Id, department.Id), default)).IsSuccess);
        Assert.Single(target.Departments);
    }
    [Theory]
    [InlineData(false, false)]
    [InlineData(true, true)]
    public async Task Internal_membership_writes_require_permission_and_matching_tenant_before_loading_targets(bool permissionAllowed, bool otherTenant)
    {
        var tenant = Guid.NewGuid();
        var user = new Mock<ICurrentUser>(); user.SetupGet(u => u.TenantId).Returns(otherTenant ? Guid.NewGuid() : tenant);
        var permission = new Mock<IPermissionChecker>();
        permission.Setup(p => p.HasPermissionAsync("User:update", It.IsAny<CancellationToken>())).ReturnsAsync(permissionAllowed);
        var work = new Mock<IUnitOfWork>(MockBehavior.Strict);
        var assign = new AssignTenantToUserCommandHandler(work.Object, NullLogger<AssignTenantToUserCommandHandler>.Instance, permission.Object, user.Object);
        var remove = new RemoveTenantFromUserCommandHandler(work.Object, NullLogger<RemoveTenantFromUserCommandHandler>.Instance, permission.Object, user.Object);
        Assert.False((await assign.Handle(new(Guid.NewGuid(), tenant, false), default)).IsSuccess);
        Assert.False((await remove.Handle(new(Guid.NewGuid(), tenant), default)).IsSuccess);
        work.VerifyNoOtherCalls();
    }
}
