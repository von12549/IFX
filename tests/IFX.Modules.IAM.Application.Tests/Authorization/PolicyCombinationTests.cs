using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access;
using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Access.Policies;
using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Modules.IAM.Domain.Access;

namespace IFX.Modules.IAM.Application.Tests.Authorization;

public class PolicyCombinationTests
{
    [Theory]
    [InlineData(false, false)] [InlineData(false, true)]
    [InlineData(true, false)] [InlineData(true, true)]
    public async Task All_applicable_global_role_policies_must_allow_regardless_of_order(bool reverse, bool secondAllows)
    {
        var actor = Guid.NewGuid();
        var user = User(actor);
        user.SetupGet(x => x.GlobalRoles).Returns(reverse ? ["PlatformSupport", "PlatformAuditor"] : ["PlatformAuditor", "PlatformSupport"]);
        var policies = new Mock<IAbacPolicyResolver>();
        var auditor = new AbacPolicy { ResourceType = "user", Action = "list" };
        var support = new AbacPolicy { ResourceType = "user", Action = "list" };
        policies.Setup(x => x.ResolvePlatformPolicyForRoleAsync("user", "list", "PlatformAuditor", It.IsAny<CancellationToken>())).ReturnsAsync(auditor);
        policies.Setup(x => x.ResolvePlatformPolicyForRoleAsync("user", "list", "PlatformSupport", It.IsAny<CancellationToken>())).ReturnsAsync(support);
        var evaluation = new Mock<IPolicyEvaluationPort>();
        evaluation.Setup(x => x.EvaluateAsync(It.IsAny<SubjectFacts>(), It.IsAny<ResourceAttributes>(), auditor, It.IsAny<EnvironmentFacts>(), null, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        evaluation.Setup(x => x.EvaluateAsync(It.IsAny<SubjectFacts>(), It.IsAny<ResourceAttributes>(), support, It.IsAny<EnvironmentFacts>(), null, It.IsAny<CancellationToken>())).ReturnsAsync(secondAllows);
        var service = Service(user, policies, evaluation, ExecutionContextSnapshot.ForPlatform(Guid.NewGuid(), Guid.NewGuid(), null, "user", actor.ToString(), "ifx", "test", 1));
        var call = () => service.AuthorizeWithResolvedPolicyAsync("user", "list", new ResourceAttributes { Type = "scope" });
        if (secondAllows) await call(); else await Assert.ThrowsAsync<ForbiddenException>(call);
        policies.Verify(x => x.ResolvePlatformPolicyForRoleAsync("user", "list", It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Exactly(2));
    }

    [Theory]
    [InlineData("rbac")]
    [InlineData("cross-tenant")]
    [InlineData("admin-tenant")]
    [InlineData("wrong-actor")]
    [InlineData("unknown-operation")]
    public async Task Mandatory_constraints_cannot_be_overridden_by_policy_or_admin(string failure)
    {
        var actor = Guid.NewGuid(); var tenant = Guid.NewGuid(); var user = User(actor);
        user.SetupGet(x => x.TenantId).Returns(tenant);
        user.SetupGet(x => x.IsGlobalAdmin).Returns(failure == "admin-tenant");
        user.SetupGet(x => x.Permissions).Returns(failure is "rbac" or "admin-tenant" ? [] : ["user:list"]);
        var policies = new Mock<IAbacPolicyResolver>(MockBehavior.Strict);
        var evaluation = new Mock<IPolicyEvaluationPort>(MockBehavior.Strict);
        var service = Service(user, policies, evaluation, ExecutionContextSnapshot.ForTenant(Guid.NewGuid(), Guid.NewGuid(), null, tenant,
            "user", failure == "wrong-actor" ? Guid.NewGuid().ToString() : actor.ToString(), "ifx", "test", 1));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.AuthorizeWithResolvedPolicyAsync(failure == "unknown-operation" ? "secret" : "user", "list",
            new ResourceAttributes { Type = "scope", TenantId = (failure == "cross-tenant" ? Guid.NewGuid() : tenant).ToString() }));
        policies.VerifyNoOtherCalls(); evaluation.VerifyNoOtherCalls();
    }

    [Theory]
    [InlineData("GlobalRoleIncludes")]
    [InlineData("AnyTenant")]
    [InlineData("Unregistered")]
    public void Tenant_management_rejects_privilege_or_unknown_templates(string template)
    {
        Assert.False(PolicyChangeRules.Valid(PolicyScope.Tenant, "user", "read", [new(template, null)]));
    }

    [Fact]
    public void Management_rejects_unknown_operations_and_arbitrary_parameters()
    {
        Assert.False(PolicyChangeRules.Valid(PolicyScope.Platform, "secret", "read", [new("SameTenant", null)]));
        Assert.False(PolicyChangeRules.Valid(PolicyScope.Tenant, "user", "read", [new("SameTenant", new() { ["tenant"] = Guid.NewGuid() })]));
        Assert.False(PolicyChangeRules.Valid(PolicyScope.Platform, "user", "read", [new("GlobalRoleIncludes", new() { ["global_role"] = "UnregisteredRole" })]));
    }

    private static Mock<ICurrentUser> User(Guid id)
    {
        var user = new Mock<ICurrentUser>(); user.SetupGet(x => x.IsAuthenticated).Returns(true);
        user.SetupGet(x => x.UserId).Returns(id); user.SetupGet(x => x.GlobalRoles).Returns([]); return user;
    }
    private static ResourceAuthorizationService Service(Mock<ICurrentUser> user, Mock<IAbacPolicyResolver> policies,
        Mock<IPolicyEvaluationPort> evaluation, ExecutionContextSnapshot snapshot)
    {
        var execution = new Mock<IExecutionContextAccessor>(); execution.SetupGet(x => x.HasCurrent).Returns(true); execution.SetupGet(x => x.Current).Returns(snapshot);
        var environment = new Mock<IAuthorizationEnvironmentPort>(); environment.Setup(x => x.GetFacts()).Returns(new EnvironmentFacts(null, null, "2026-09-12T00:00:00Z"));
        return new(user.Object, policies.Object, evaluation.Object, environment.Object, execution.Object);
    }
}
