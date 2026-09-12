using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access;
using IFX.Modules.IAM.Application.Access.Abac.Policies;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Ports.Authorization;
using Moq;
using Xunit;

namespace IFX.Modules.IAM.Application.Tests.Authorization;

public class ResourceAuthorizationTests
{
    [Theory]
    [InlineData("tenant", true)]
    [InlineData("tenant", false)]
    [InlineData("role", true)]
    [InlineData("missing", false)]
    [InlineData("admin", true)]
    public async Task Preserves_baseline_policy_selection_and_enforces_denial(string scenario, bool allowed)
    {
        var tenant = Guid.NewGuid();
        var user = new Mock<ICurrentUser>();
        user.SetupGet(x => x.TenantId).Returns(tenant);
        user.SetupGet(x => x.UserId).Returns(Guid.NewGuid());
        user.SetupGet(x => x.GlobalRoles).Returns(scenario == "role" ? ["PlatformSupport", "PlatformAuditor"] : []);
        user.SetupGet(x => x.IsGlobalAdmin).Returns(scenario == "admin");
        var policies = new Mock<IAbacPolicyResolver>(MockBehavior.Strict);
        var policy = new AbacPolicy { ResourceType = "user", Action = "read", Conditions = [new() { Template = BuiltInTemplates.SameTenant }] };
        policies.Setup(x => x.ResolveTenantPolicyAsync(tenant, "user", "read", It.IsAny<CancellationToken>()))
            .ReturnsAsync(scenario == "missing" ? null : policy);
        policies.Setup(x => x.ResolvePlatformPolicyForRoleAsync("user", "read", "PlatformSupport", It.IsAny<CancellationToken>()))
            .ReturnsAsync(policy);
        var evaluator = new Mock<IPolicyEvaluationPort>();
        evaluator.Setup(x => x.EvaluateAsync(It.IsAny<SubjectFacts>(), It.IsAny<ResourceAttributes>(), policy,
            It.IsAny<EnvironmentFacts>(), null, It.IsAny<CancellationToken>())).ReturnsAsync(allowed);
        var environment = new Mock<IAuthorizationEnvironmentPort>();
        environment.Setup(x => x.GetFacts()).Returns(new EnvironmentFacts(null, null, "2026-09-12T00:00:00Z"));
        var service = new ResourceAuthorizationService(user.Object, policies.Object, evaluator.Object, environment.Object,
            Mock.Of<IExecutionContextAccessor>());
        var executed = false;
        async Task Execute()
        {
            await service.AuthorizeWithResolvedPolicyAsync("user", "read", new ResourceAttributes { Type = "user", TenantId = tenant.ToString() });
            executed = true;
        }
        if (allowed) await Execute(); else await Assert.ThrowsAsync<ForbiddenException>(Execute);
        Assert.Equal(allowed, executed);
        if (scenario == "admin") { policies.VerifyNoOtherCalls(); evaluator.VerifyNoOtherCalls(); }
        if (scenario == "missing") evaluator.VerifyNoOtherCalls();
        if (scenario == "role") policies.Verify(x => x.ResolvePlatformPolicyForRoleAsync("user", "read", "PlatformSupport", It.IsAny<CancellationToken>()), Times.Once);
    }
}
