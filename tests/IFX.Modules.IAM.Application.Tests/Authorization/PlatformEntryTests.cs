using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access.GlobalRoles.Commands.AssignGlobalRole;
using IFX.Modules.IAM.Application.Access.GlobalRoles.Commands.RemoveGlobalRole;
using IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.ListGlobalRoles;
using IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.GetUserGlobalRoles;
using IFX.Modules.IAM.Application.Access.Policies.Queries.GetPlatformPolicies;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Ports.Authorization;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tests.Authorization;

public class PlatformEntryTests
{
    [Fact]
    public async Task Internal_global_role_entries_do_not_read_or_write_when_permission_boundary_denies()
    {
        var unit = new Mock<IUnitOfWork>(MockBehavior.Strict);
        var user = new Mock<ICurrentUser>(); user.SetupGet(x => x.IsGlobalAdmin).Returns(true);
        var permission = Mock.Of<IPermissionChecker>();
        var assign = new AssignGlobalRoleCommandHandler(unit.Object, user.Object, Mock.Of<ILogger<AssignGlobalRoleCommandHandler>>(), permission);
        var remove = new RemoveGlobalRoleCommandHandler(unit.Object, user.Object, Mock.Of<ILogger<RemoveGlobalRoleCommandHandler>>(), permission);
        var list = new ListGlobalRolesQueryHandler(unit.Object, Mock.Of<ILogger<ListGlobalRolesQueryHandler>>(), permission);
        var byUser = new GetUserGlobalRolesQueryHandler(unit.Object, Mock.Of<ILogger<GetUserGlobalRolesQueryHandler>>(), permission);
        Assert.False((await assign.Handle(new(Guid.NewGuid(), Guid.NewGuid()), default)).IsSuccess);
        Assert.False((await remove.Handle(new(Guid.NewGuid(), Guid.NewGuid()), default)).IsSuccess);
        Assert.False((await list.Handle(new(), default)).IsSuccess);
        Assert.False((await byUser.Handle(new(Guid.NewGuid()), default)).IsSuccess);
        unit.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Platform_policy_query_requires_ABAC_before_repository_read()
    {
        var unit = new Mock<IUnitOfWork>(MockBehavior.Strict);
        var authorization = new Mock<IResourceAuthorizationService>();
        authorization.Setup(x => x.AuthorizeWithResolvedPolicyAsync("platform_policy", "list", It.IsAny<ResourceAttributes>(),
            null, It.IsAny<CancellationToken>())).ThrowsAsync(new ForbiddenException());
        var handler = new GetPlatformPoliciesQueryHandler(unit.Object, Mock.Of<ILogger<GetPlatformPoliciesQueryHandler>>(), authorization.Object);
        Assert.False((await handler.Handle(new(), default)).IsSuccess);
        unit.VerifyNoOtherCalls();
    }
}
