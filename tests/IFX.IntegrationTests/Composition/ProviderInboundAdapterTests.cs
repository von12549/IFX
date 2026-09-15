using IFX.BuildingBlocks.Application.Context;
using IFX.ApiHost.Runtime;
using IFX.Modules.CRM.Application.AccountCompliance;
using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Modules.CRM.Infrastructure.Integrations.Inbound;
using IFX.Modules.Registry.Application.ClassSubscriptionAvailability;
using IFX.Modules.Registry.Application.Ports;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Modules.Registry.Infrastructure.Integrations.Inbound;
using IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.CRM;
using IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.Registry;
using IFX.Platform.Context.Contracts.Context;
using IFX.Platform.Context.Runtime.Inbound;
using IFX.Platform.Context.Runtime.Outbound;
using Moq;

namespace IFX.IntegrationTests.Composition;

public sealed class ProviderInboundAdapterTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");

    [Fact]
    public async Task Real_in_process_chain_uses_provider_child_scope_and_provider_data_ports()
    {
        var execution = new ExecutionContextAccessor();
        var outer = Current();
        var accountId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        var crmData = new Mock<IAccountComplianceDataPort>();
        var registryData = new Mock<IClassSubscriptionDataPort>();
        crmData.Setup(value => value.IsInvestmentAccountKycApprovedAsync(accountId, TenantId, It.IsAny<CancellationToken>()))
            .Callback(() => execution.Current.Source.Component.Should().Be("crm-provider"))
            .ReturnsAsync(true);
        registryData.Setup(value => value.IsClassOpenForSubscriptionAsync(classId, TenantId, It.IsAny<CancellationToken>()))
            .Callback(() => execution.Current.Source.Component.Should().Be("registry-provider"))
            .ReturnsAsync(false);
        var crmInbound = CrmAdapter(new AccountComplianceUseCase(crmData.Object, execution), execution, execution);
        var registryInbound = RegistryAdapter(
            new ClassSubscriptionAvailabilityUseCase(registryData.Object, execution), execution, execution);
        var outboundContextFactory = new OutboundContractRequestContextFactory(execution);
        var crmOutbound = new AccountComplianceAdapter(outboundContextFactory, crmInbound);
        var registryOutbound = new ClassSubscriptionAvailabilityAdapter(outboundContextFactory, registryInbound);

        using (execution.Push(outer))
        {
            (await crmOutbound.IsApprovedAsync(accountId, TenantId)).Should().BeTrue();
            (await registryOutbound.IsOpenAsync(classId, TenantId)).Should().BeFalse();
            execution.Current.Should().Be(outer);
        }

        execution.HasCurrent.Should().BeFalse();
        crmData.VerifyAll();
        registryData.VerifyAll();
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task CrmInbound_ValidatesAndDelegatesInsideChildScope(bool approved)
    {
        var current = Current();
        var useCase = new Mock<IAccountComplianceUseCase>();
        var accountId = Guid.NewGuid();
        useCase.Setup(value => value.IsApprovedAsync(accountId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(approved);
        ExecutionContextSnapshot? child = null;
        var scopeFactory = ScopeFactory(value => child = value);
        var adapter = CrmAdapter(useCase.Object, scopeFactory.Object, Accessor(current));

        var response = await adapter.CheckAsync(new(accountId, TenantId), Context(current));

        response.IsApproved.Should().Be(approved);
        child.Should().NotBeNull();
        child!.CorrelationId.Should().Be(current.CorrelationId);
        child.OperationId.Should().NotBe(current.OperationId);
        child.CausationId!.Value.Value.Should().Be(current.OperationId.Value);
        child.TenantId.Should().Be(TenantId);
        useCase.Verify(value => value.IsApprovedAsync(accountId, TenantId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("unknown-consumer", AccountComplianceInboundAdapter.ConsumerDenied)]
    [InlineData("untrusted", AccountComplianceInboundAdapter.ContextInvalid)]
    [InlineData("actor-mismatch", AccountComplianceInboundAdapter.ContextInvalid)]
    [InlineData("tenant-mismatch", AccountComplianceInboundAdapter.TenantMismatch)]
    [InlineData("source-v2", AccountComplianceInboundAdapter.ConsumerDenied)]
    public async Task CrmInbound_RejectsBeforeApplication(string scenario, string expected)
    {
        var current = Current();
        var useCase = new Mock<IAccountComplianceUseCase>(MockBehavior.Strict);
        var adapter = CrmAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));
        var context = Context(current,
            source: scenario == "unknown-consumer" ? "unknown" : "transaction",
            provenance: scenario == "untrusted" ? ContractRequestContext.SynthesizedProvenance : ContractRequestContext.TrustedProvenance,
            actorId: scenario == "actor-mismatch" ? "other-actor" : current.Actor.Id,
            sourceVersion: scenario == "source-v2" ? 2 : 1);
        var requestedTenant = scenario == "tenant-mismatch" ? Guid.NewGuid() : TenantId;

        var failure = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), requestedTenant), context));

        failure.Code.Should().Be(expected);
        useCase.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CrmInbound_MapsApplicationFailureWithoutLeakingMessage()
    {
        var current = Current();
        var useCase = new Mock<IAccountComplianceUseCase>();
        useCase.Setup(value => value.IsApprovedAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("database-secret"));
        var adapter = CrmAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));

        var failure = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), TenantId), Context(current)));

        failure.Code.Should().Be(AccountComplianceInboundAdapter.Unavailable);
        failure.Message.Should().NotContain("database-secret");
        failure.InnerException.Should().BeNull();
    }

    [Fact]
    public async Task CrmInbound_RequiresAmbientTrustedCaller()
    {
        var current = Current();
        var useCase = new Mock<IAccountComplianceUseCase>(MockBehavior.Strict);
        var adapter = CrmAdapter(useCase.Object, ScopeFactory().Object, Mock.Of<IExecutionContextAccessor>());

        var failure = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), TenantId), Context(current)));

        failure.Code.Should().Be(AccountComplianceInboundAdapter.ContextInvalid);
        useCase.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CrmInbound_PropagatesCallerCancellation()
    {
        var current = Current();
        var useCase = new Mock<IAccountComplianceUseCase>(MockBehavior.Strict);
        var adapter = CrmAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), TenantId), Context(current), cancellation.Token));

        useCase.VerifyNoOtherCalls();
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task RegistryInbound_DelegatesProviderOwnedDecision(bool isOpen)
    {
        var current = Current();
        var useCase = new Mock<IClassSubscriptionAvailabilityUseCase>();
        var classId = Guid.NewGuid();
        useCase.Setup(value => value.IsOpenAsync(classId, TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(isOpen);
        var adapter = RegistryAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));

        var response = await adapter.CheckAsync(new(classId, TenantId), Context(current));

        response.IsOpen.Should().Be(isOpen);
        useCase.Verify(value => value.IsOpenAsync(classId, TenantId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData("unknown-consumer", ClassSubscriptionAvailabilityInboundAdapter.ConsumerDenied)]
    [InlineData("untrusted", ClassSubscriptionAvailabilityInboundAdapter.ContextInvalid)]
    [InlineData("tenant-mismatch", ClassSubscriptionAvailabilityInboundAdapter.TenantMismatch)]
    public async Task RegistryInbound_RejectsBeforeApplication(string scenario, string expected)
    {
        var current = Current();
        var useCase = new Mock<IClassSubscriptionAvailabilityUseCase>(MockBehavior.Strict);
        var adapter = RegistryAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));
        var context = Context(current,
            source: scenario == "unknown-consumer" ? "unknown" : "transaction",
            provenance: scenario == "untrusted" ? ContractRequestContext.SynthesizedProvenance : ContractRequestContext.TrustedProvenance);
        var requestedTenant = scenario == "tenant-mismatch" ? Guid.NewGuid() : TenantId;

        var failure = await Assert.ThrowsAsync<ClassSubscriptionAvailabilityContractException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), requestedTenant), context));

        failure.Code.Should().Be(expected);
        useCase.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task RegistryInbound_MapsProviderTimeoutToStableUnavailable()
    {
        var current = Current();
        var useCase = new Mock<IClassSubscriptionAvailabilityUseCase>();
        useCase.Setup(value => value.IsOpenAsync(It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new TimeoutException("internal timeout"));
        var adapter = RegistryAdapter(useCase.Object, ScopeFactory().Object, Accessor(current));

        var failure = await Assert.ThrowsAsync<ClassSubscriptionAvailabilityContractException>(() =>
            adapter.CheckAsync(new(Guid.NewGuid(), TenantId), Context(current)));

        failure.Code.Should().Be(ClassSubscriptionAvailabilityInboundAdapter.Unavailable);
        failure.Message.Should().NotContain("internal timeout");
    }

    [Fact]
    public void ContractContext_RejectsUnsupportedVersionAndMissingScopeAtConstruction()
    {
        var current = Current();
        Action unsupportedVersion = () => new ContractRequestContext(Guid.NewGuid(), current.CorrelationId.Value,
            current.OperationId.Value, ContractRequestContext.TenantScope, TenantId, "service", current.Actor.Id,
            "ifx", "transaction", 1, version: 2);
        Action missingScope = () => new ContractRequestContext(Guid.NewGuid(), current.CorrelationId.Value,
            current.OperationId.Value, "", TenantId, "service", current.Actor.Id,
            "ifx", "transaction", 1);

        unsupportedVersion.Should().Throw<ArgumentOutOfRangeException>();
        missingScope.Should().Throw<ArgumentException>();
    }

    private static ExecutionContextSnapshot Current() => ExecutionContextSnapshot.ForTenant(
        Guid.NewGuid(), Guid.NewGuid(), null, TenantId,
        "service", "transaction-service", "ifx", "api-host", 1);

    private static IExecutionContextAccessor Accessor(ExecutionContextSnapshot current)
    {
        var accessor = new Mock<IExecutionContextAccessor>();
        accessor.SetupGet(value => value.HasCurrent).Returns(true);
        accessor.SetupGet(value => value.Current).Returns(current);
        return accessor.Object;
    }

    private static AccountComplianceInboundAdapter CrmAdapter(
        IAccountComplianceUseCase useCase,
        IExecutionContextScopeFactory scopeFactory,
        IExecutionContextAccessor accessor) => new(
        useCase,
        scopeFactory,
        new InboundContractContextValidator(accessor),
        new ProviderExecutionContextFactory());

    private static ClassSubscriptionAvailabilityInboundAdapter RegistryAdapter(
        IClassSubscriptionAvailabilityUseCase useCase,
        IExecutionContextScopeFactory scopeFactory,
        IExecutionContextAccessor accessor) => new(
        useCase,
        scopeFactory,
        new InboundContractContextValidator(accessor),
        new ProviderExecutionContextFactory());

    private static Mock<IExecutionContextScopeFactory> ScopeFactory(Action<ExecutionContextSnapshot>? observe = null)
    {
        var factory = new Mock<IExecutionContextScopeFactory>();
        factory.Setup(value => value.Push(It.IsAny<ExecutionContextSnapshot>()))
            .Callback<ExecutionContextSnapshot>(value => observe?.Invoke(value))
            .Returns(Mock.Of<IDisposable>());
        return factory;
    }

    private static ContractRequestContext Context(
        ExecutionContextSnapshot current,
        string source = "transaction",
        string provenance = ContractRequestContext.TrustedProvenance,
        string? actorId = null,
        int sourceVersion = 1) => new(
        Guid.NewGuid(), current.CorrelationId.Value, current.OperationId.Value,
        ContractRequestContext.TenantScope, current.TenantId,
        current.Actor.Kind.ToString().ToLowerInvariant(), actorId ?? current.Actor.Id,
        "ifx", source, sourceVersion, provenance);
}
