using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.Platform.Context.Contracts;
using IFX.Platform.Context.Contracts.Context;
using Contract = IFX.Modules.IAM.Contracts.V1.Authorization;

namespace IFX.Modules.IAM.Application.Tests.Authorization;

public sealed class ContractContextTests
{
    [Theory]
    [InlineData("valid", true)]
    [InlineData("actor-kind", false)]
    [InlineData("actor-id", false)]
    [InlineData("tenant-scope", false)]
    [InlineData("untrusted", false)]
    [InlineData("unknown-caller", false)]
    [InlineData("missing-execution", false)]
    [InlineData("service-execution", false)]
    public async Task Provider_rejects_forged_or_missing_context_before_policy_execution(string scenario, bool allowed)
    {
        var id = Guid.NewGuid();
        var current = new Mock<ICurrentUser>(); current.SetupGet(u => u.IsAuthenticated).Returns(true);
        current.SetupGet(u => u.UserId).Returns(id); current.SetupGet(u => u.IsGlobalAdmin).Returns(true);
        var snapshot = ExecutionContextSnapshot.ForPlatform(Guid.NewGuid(), Guid.NewGuid(), null,
            scenario == "service-execution" ? "service" : "user", id.ToString(), "ifx", "crm", 1);
        var execution = new Mock<IExecutionContextAccessor>(); execution.SetupGet(e => e.HasCurrent).Returns(scenario != "missing-execution");
        execution.SetupGet(e => e.Current).Returns(snapshot);
        var policy = new Mock<IAbacPolicyResolver>(MockBehavior.Strict); var evaluation = new Mock<IPolicyEvaluationPort>(MockBehavior.Strict);
        var service = new ResourceAuthorizationService(current.Object, policy.Object, evaluation.Object, Mock.Of<IAuthorizationEnvironmentPort>(), execution.Object);
        var context = new ContractRequestContext(Guid.NewGuid(), snapshot.CorrelationId.Value, null,
            scenario == "tenant-scope" ? "tenant" : "platform", scenario == "tenant-scope" ? Guid.NewGuid() : null,
            scenario == "actor-kind" ? "service" : "user", scenario == "actor-id" ? Guid.NewGuid().ToString() : id.ToString(),
            "ifx", scenario == "unknown-caller" ? "unknown" : "crm", 1, scenario == "untrusted" ? "synthesized" : "trusted");
        var result = await service.AuthorizeAsync(new("user", "read", new Contract.ResourceAttributes { Type = "user", Id = "target", IsActive = "true" }), context);
        Assert.Equal(allowed, result.Allowed); policy.VerifyNoOtherCalls(); evaluation.VerifyNoOtherCalls();
    }
}
