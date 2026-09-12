using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Contracts.V1.Authorization;
using IFX.Platform.Context.Contracts.Context;
using Moq;
using Xunit;

namespace IFX.IntegrationTests.Composition;

public class AuthorizationAdapterTests
{
    [Theory]
    [InlineData("crm", true)] [InlineData("crm", false)]
    [InlineData("registry", true)] [InlineData("registry", false)]
    [InlineData("holdings", true)] [InlineData("holdings", false)]
    [InlineData("transaction", true)] [InlineData("transaction", false)]
    public async Task All_resource_adapters_map_scope_and_enforce_provider_decision(string module, bool allow)
    {
        var tenant = Guid.NewGuid();
        var snapshot = ExecutionContextSnapshot.ForTenant(Guid.NewGuid(), Guid.NewGuid(), null, tenant, "user", "actor-1", "ifx", "api-host", 1);
        var execution = new Mock<IExecutionContextAccessor>();
        execution.SetupGet(x => x.HasCurrent).Returns(true);
        execution.SetupGet(x => x.Current).Returns(snapshot);
        var contract = new Mock<IResourceAuthorizationContract>();
        contract.Setup(x => x.AuthorizeAsync(It.IsAny<ResourceAuthorizationRequest>(), It.IsAny<ContractRequestContext>(), It.IsAny<CancellationToken>()))
            .Callback<ResourceAuthorizationRequest, ContractRequestContext, CancellationToken>((request, context, _) =>
            {
                Assert.Equal(tenant.ToString(), request.Resource.TenantId);
                Assert.Equal("fund", request.ResourceType);
                Assert.Equal("read", request.Action);
                Assert.Equal(module, context.SourceComponent);
                Assert.Equal(snapshot.CorrelationId.Value, context.CorrelationId);
                Assert.Equal(snapshot.OperationId.Value, context.CausationId);
                Assert.Equal("trusted", context.Provenance);
            }).ReturnsAsync(new ResourceAuthorizationResponse(allow, allow ? "policy_allow" : "policy_deny"));
        Func<Task> invoke = module switch
        {
            "crm" => () => new Modules.CRM.Infrastructure.Integrations.ResourceAuthorizationAdapter(contract.Object, execution.Object)
                .AuthorizeWithResolvedPolicyAsync("fund", "read", new Modules.CRM.Application.Ports.Authorization.ResourceAttributes { TenantId = tenant.ToString() }),
            "registry" => () => new Modules.Registry.Infrastructure.Integrations.ResourceAuthorizationAdapter(contract.Object, execution.Object)
                .AuthorizeWithResolvedPolicyAsync("fund", "read", new Modules.Registry.Application.Ports.Authorization.ResourceAttributes { TenantId = tenant.ToString() }),
            "holdings" => () => new Modules.Holdings.Infrastructure.Integrations.ResourceAuthorizationAdapter(contract.Object, execution.Object)
                .AuthorizeWithResolvedPolicyAsync("fund", "read", new Modules.Holdings.Application.Ports.Authorization.ResourceAttributes { TenantId = tenant.ToString() }),
            _ => () => new Modules.Transaction.Infrastructure.Integrations.ResourceAuthorizationAdapter(contract.Object, execution.Object)
                .AuthorizeWithResolvedPolicyAsync("fund", "read", new Modules.Transaction.Application.Ports.Authorization.ResourceAttributes { TenantId = tenant.ToString() })
        };
        if (allow) await invoke(); else await Assert.ThrowsAsync<ForbiddenException>(invoke);
    }

    [Fact]
    public async Task Worker_without_trusted_context_cannot_call_IAM()
    {
        var contract = new Mock<IResourceAuthorizationContract>(MockBehavior.Strict);
        var adapter = new Modules.Transaction.Infrastructure.Integrations.ResourceAuthorizationAdapter(contract.Object, Mock.Of<IExecutionContextAccessor>());
        await Assert.ThrowsAsync<ForbiddenException>(() => adapter.AuthorizeWithResolvedPolicyAsync("fund", "read",
            new Modules.Transaction.Application.Ports.Authorization.ResourceAttributes()));
        contract.VerifyNoOtherCalls();
    }
}
