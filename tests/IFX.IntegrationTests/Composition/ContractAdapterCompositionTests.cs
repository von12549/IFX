using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Infrastructure.Integrations.Inbound;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Modules.Registry.Infrastructure.Integrations.Inbound;
using IFX.Modules.Transaction.Application.Ports;
using IFX.Modules.Transaction.Infrastructure.Integrations.Outbound.CRM;
using IFX.IntegrationTests.Fixtures;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using IFX.Platform.Context.Runtime.Outbound;

namespace IFX.IntegrationTests.Composition;

public sealed class ContractAdapterCompositionTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");

    [Fact]
    public void RootComposition_RegistersOneProviderAndOneConsumerAdapterPerCapability()
    {
        using var factory = new CustomWebApplicationFactory();
        using var scope = factory.Services.CreateScope();

        scope.ServiceProvider.GetServices<IAccountComplianceContract>().Should().ContainSingle();
        scope.ServiceProvider.GetServices<IClassSubscriptionAvailabilityContract>().Should().ContainSingle();
        scope.ServiceProvider.GetRequiredService<IAccountComplianceContract>()
            .Should().BeOfType<AccountComplianceInboundAdapter>();
        scope.ServiceProvider.GetRequiredService<IClassSubscriptionAvailabilityContract>()
            .Should().BeOfType<ClassSubscriptionAvailabilityInboundAdapter>();
        scope.ServiceProvider.GetServices<IAccountCompliancePort>().Should().ContainSingle();
        scope.ServiceProvider.GetServices<IClassSubscriptionAvailabilityPort>().Should().ContainSingle();
    }

    [Fact]
    public async Task RealInProcessAdapter_GeneratesFreshRequestContextAndPreservesTrustedChain()
    {
        var current = ExecutionContextSnapshot.ForTenant(
            Guid.Parse("60a0e08c-2dd9-4f76-af07-e624f5adbe53"),
            Guid.Parse("1571d680-91cf-4f7c-853d-49cb816376e7"),
            null,
            TenantId,
            "user",
            "actor-1",
            "ifx",
            "api-host",
            1);
        var accessor = new FixedExecutionContextAccessor(current);
        var observed = new List<IFX.Platform.Context.Contracts.Context.ContractRequestContext>();
        var contract = new Mock<IAccountComplianceContract>();
        contract.Setup(provider => provider.CheckAsync(
                It.IsAny<AccountComplianceRequest>(),
                It.IsAny<IFX.Platform.Context.Contracts.Context.ContractRequestContext>(),
                It.IsAny<CancellationToken>()))
            .Callback<AccountComplianceRequest, IFX.Platform.Context.Contracts.Context.ContractRequestContext, CancellationToken>(
                (_, context, _) => observed.Add(context))
            .ReturnsAsync(new AccountComplianceResponse(true));
        var adapter = new AccountComplianceAdapter(
            new OutboundContractRequestContextFactory(accessor),
            contract.Object);

        await adapter.IsApprovedAsync(Guid.NewGuid(), TenantId, CancellationToken.None);
        await adapter.IsApprovedAsync(Guid.NewGuid(), TenantId, CancellationToken.None);

        observed.Should().HaveCount(2);
        observed.Select(context => context.RequestId).Should().OnlyHaveUniqueItems();
        observed.Should().OnlyContain(context =>
            context.CorrelationId == current.CorrelationId.Value &&
            context.CausationId == current.OperationId.Value &&
            context.TenantId == TenantId &&
            context.SourceSystem == "ifx" &&
            context.SourceComponent == "transaction" &&
            context.Provenance == "trusted");
    }

    [Theory]
    [InlineData("timeout")]
    [InlineData("unavailable")]
    [InlineData("tenant-mismatch")]
    public async Task RealInProcessAdapter_FailsClosedForMappedBoundaryFailures(string failure)
    {
        var current = ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, TenantId,
            "service", "transaction-service", "ifx", "api-host", 1);
        var contract = new Mock<IAccountComplianceContract>();
        contract.Setup(provider => provider.CheckAsync(
                It.IsAny<AccountComplianceRequest>(),
                It.IsAny<IFX.Platform.Context.Contracts.Context.ContractRequestContext>(),
                It.IsAny<CancellationToken>()))
            .ThrowsAsync(failure == "timeout"
                ? new TimeoutException()
                : new AccountComplianceContractException("contract_unavailable"));
        var adapter = new AccountComplianceAdapter(
            new OutboundContractRequestContextFactory(new FixedExecutionContextAccessor(current)),
            contract.Object);
        var requestedTenant = failure == "tenant-mismatch" ? Guid.NewGuid() : TenantId;

        var result = await adapter.IsApprovedAsync(Guid.NewGuid(), requestedTenant, CancellationToken.None);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task RealInProcessAdapter_PropagatesCallerCancellation()
    {
        var current = ExecutionContextSnapshot.ForTenant(
            Guid.NewGuid(), Guid.NewGuid(), null, TenantId,
            "service", "transaction-service", "ifx", "api-host", 1);
        var contract = new Mock<IAccountComplianceContract>();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        contract.Setup(provider => provider.CheckAsync(
                It.IsAny<AccountComplianceRequest>(),
                It.IsAny<IFX.Platform.Context.Contracts.Context.ContractRequestContext>(),
                It.IsAny<CancellationToken>()))
            .Returns((AccountComplianceRequest _, IFX.Platform.Context.Contracts.Context.ContractRequestContext _, CancellationToken token) =>
                Task.FromCanceled<AccountComplianceResponse>(token));
        var adapter = new AccountComplianceAdapter(
            new OutboundContractRequestContextFactory(new FixedExecutionContextAccessor(current)),
            contract.Object);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            adapter.IsApprovedAsync(Guid.NewGuid(), TenantId, cancellation.Token));
    }

    private sealed class FixedExecutionContextAccessor(ExecutionContextSnapshot current) : IExecutionContextAccessor
    {
        public bool HasCurrent => true;
        public ExecutionContextSnapshot Current => current;
    }
}
