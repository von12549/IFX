using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Client.Authorization;
using IFX.Modules.IAM.Contracts.V1.Authorization;
using IFX.Platform.Context.Contracts.Context;
using IFX.Platform.Context.Runtime;
using IFX.Platform.Context.Runtime.Outbound;
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
                Assert.Equal("fund", request.Resource.Type);
                Assert.Equal("resource-1", request.Resource.Id);
                Assert.Equal("true", request.Resource.IsActive);
                Assert.Equal("owner-1", request.Resource.OwnerId);
                Assert.Equal(["ops", "risk"], request.Resource.Departments);
                Assert.Equal(module, context.SourceComponent);
                Assert.Equal(snapshot.CorrelationId.Value, context.CorrelationId);
                Assert.Equal(snapshot.OperationId.Value, context.CausationId);
                Assert.Equal("trusted", context.Provenance);
            }).ReturnsAsync(new ResourceAuthorizationResponse(allow, allow ? "policy_allow" : "policy_deny"));
        Func<Task> invoke = module switch
        {
            "crm" => () => new Modules.CRM.Infrastructure.Integrations.Outbound.IAM.ResourceAuthorizationAdapter(Client(contract.Object, execution.Object))
                .AuthorizeWithResolvedPolicyAsync("fund", "read", Resource(tenant)),
            "registry" => () => new Modules.Registry.Infrastructure.Integrations.Outbound.IAM.ResourceAuthorizationAdapter(Client(contract.Object, execution.Object))
                .AuthorizeWithResolvedPolicyAsync("fund", "read", Resource(tenant)),
            "holdings" => () => new Modules.Holdings.Infrastructure.Integrations.Outbound.IAM.ResourceAuthorizationAdapter(Client(contract.Object, execution.Object))
                .AuthorizeWithResolvedPolicyAsync("fund", "read", Resource(tenant)),
            _ => () => new Modules.Transaction.Infrastructure.Integrations.Outbound.IAM.ResourceAuthorizationAdapter(Client(contract.Object, execution.Object))
                .AuthorizeWithResolvedPolicyAsync("fund", "read", Resource(tenant))
        };
        if (allow) await invoke(); else await Assert.ThrowsAsync<ForbiddenException>(invoke);
    }

    [Fact]
    public async Task Worker_without_trusted_context_cannot_call_IAM()
    {
        var contract = new Mock<IResourceAuthorizationContract>(MockBehavior.Strict);
        var adapter = new Modules.Transaction.Infrastructure.Integrations.Outbound.IAM.ResourceAuthorizationAdapter(
            Client(contract.Object, Mock.Of<IExecutionContextAccessor>()));
        await Assert.ThrowsAsync<ForbiddenException>(() => adapter.AuthorizeWithResolvedPolicyAsync("fund", "read",
            new IFX.BuildingBlocks.Security.Authorization.ResourceAttributes()));
        contract.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Iam_client_rejects_runtime_parameters_before_provider_call()
    {
        var contract = new Mock<IResourceAuthorizationContract>(MockBehavior.Strict);
        var snapshot = ExecutionContextSnapshot.ForPlatform(
            Guid.NewGuid(), Guid.NewGuid(), null, "user", "actor-1", "ifx", "api-host", 1);
        var execution = new Mock<IExecutionContextAccessor>();
        execution.SetupGet(value => value.HasCurrent).Returns(true);
        execution.SetupGet(value => value.Current).Returns(snapshot);

        var action = () => Client(contract.Object, execution.Object).AuthorizeAsync(
            new ContractComponentIdentity("ifx", "crm", 1),
            "fund",
            "read",
            Resource(Guid.NewGuid()),
            new Dictionary<string, object> { ["override"] = true });

        await action.Should().ThrowAsync<ForbiddenException>();
        contract.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task Iam_client_propagates_caller_cancellation()
    {
        var tenant = Guid.NewGuid();
        var snapshot = ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, tenant, "user", "actor-1", "ifx", "api-host", 1);
        var execution = new Mock<IExecutionContextAccessor>();
        execution.SetupGet(value => value.HasCurrent).Returns(true);
        execution.SetupGet(value => value.Current).Returns(snapshot);
        var contract = new Mock<IResourceAuthorizationContract>();
        contract.Setup(value => value.AuthorizeAsync(
                It.IsAny<ResourceAuthorizationRequest>(),
                It.IsAny<ContractRequestContext>(),
                It.IsAny<CancellationToken>()))
            .Returns<ResourceAuthorizationRequest, ContractRequestContext, CancellationToken>(
                (_, _, token) => Task.FromCanceled<ResourceAuthorizationResponse>(token));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        var action = () => Client(contract.Object, execution.Object).AuthorizeAsync(
            new ContractComponentIdentity("ifx", "crm", 1),
            "fund",
            "read",
            Resource(tenant),
            cancellationToken: cancellation.Token);

        await action.Should().ThrowAsync<OperationCanceledException>();
    }

    [Fact]
    public async Task Iam_client_does_not_expose_provider_denial_reason()
    {
        var snapshot = ExecutionContextSnapshot.ForPlatform(
            Guid.NewGuid(), Guid.NewGuid(), null, "user", "actor-1", "ifx", "api-host", 1);
        var execution = new Mock<IExecutionContextAccessor>();
        execution.SetupGet(value => value.HasCurrent).Returns(true);
        execution.SetupGet(value => value.Current).Returns(snapshot);
        var contract = new Mock<IResourceAuthorizationContract>();
        contract.Setup(value => value.AuthorizeAsync(
                It.IsAny<ResourceAuthorizationRequest>(),
                It.IsAny<ContractRequestContext>(),
                It.IsAny<CancellationToken>()))
            .Callback<ResourceAuthorizationRequest, ContractRequestContext, CancellationToken>((_, context, _) =>
            {
                context.Scope.Should().Be(ContractRequestContext.PlatformScope);
                context.TenantId.Should().BeNull();
            })
            .ReturnsAsync(new ResourceAuthorizationResponse(false, "sensitive-policy-rule-name"));

        var action = () => Client(contract.Object, execution.Object).AuthorizeAsync(
            new ContractComponentIdentity("ifx", "crm", 1),
            "fund",
            "read",
            Resource(Guid.NewGuid()));

        var denial = await action.Should().ThrowAsync<ForbiddenException>();
        denial.Which.Message.Should().Be("Access denied by policy.");
        denial.Which.Message.Should().NotContain("sensitive-policy-rule-name");
    }

    private static IamResourceAuthorizationClient Client(
        IResourceAuthorizationContract contract,
        IExecutionContextAccessor execution) => new(
        contract,
        new OutboundContractRequestContextFactory(execution));

    private static IFX.BuildingBlocks.Security.Authorization.ResourceAttributes Resource(Guid tenant) => new()
    {
        Type = "fund",
        Id = "resource-1",
        TenantId = tenant.ToString(),
        IsActive = "true",
        OwnerId = "owner-1",
        Departments = ["ops", "risk"]
    };
}
