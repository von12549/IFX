using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.CRM.Application.Contracts;
using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.CRM.Application.Tests.Contracts;

public sealed class AccountComplianceContractTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");
    private readonly Mock<IAccountComplianceDataPort> _dataPort = new();
    private readonly Mock<IExecutionContextScopeFactory> _scopeFactory = new();

    public AccountComplianceContractTests()
    {
        _scopeFactory.Setup(factory => factory.Push(It.IsAny<ExecutionContextSnapshot>()))
            .Returns(Mock.Of<IDisposable>());
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task CheckAsync_ReturnsCurrentCommittedDecision(bool approved)
    {
        _dataPort.Setup(port => port.IsInvestmentAccountKycApprovedAsync(
                It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(approved);
        var contract = CreateContract();

        var response = await contract.CheckAsync(
            new AccountComplianceRequest(Guid.NewGuid(), TenantId),
            CreateContext(),
            CancellationToken.None);

        response.IsApproved.Should().Be(approved);
    }

    [Fact]
    public async Task CheckAsync_CreatesIsolatedTrustedProviderScope()
    {
        ExecutionContextSnapshot? child = null;
        _scopeFactory.Setup(factory => factory.Push(It.IsAny<ExecutionContextSnapshot>()))
            .Callback<ExecutionContextSnapshot>(context => child = context)
            .Returns(Mock.Of<IDisposable>());
        _dataPort.Setup(port => port.IsInvestmentAccountKycApprovedAsync(
                It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        var inbound = CreateContext();

        await CreateContract().CheckAsync(
            new AccountComplianceRequest(Guid.NewGuid(), TenantId), inbound, CancellationToken.None);

        child.Should().NotBeNull();
        child!.CorrelationId.Value.Should().Be(inbound.CorrelationId);
        child.OperationId.Value.Should().NotBe(Guid.Empty).And.NotBe(inbound.CausationId!.Value);
        child.CausationId!.Value.Value.Should().Be(inbound.CausationId.Value);
        child.TenantId.Should().Be(TenantId);
        child.Source.Component.Should().Be("crm-provider");
    }

    [Fact]
    public async Task CheckAsync_RejectsUnknownConsumerBeforeOtherContextFailures()
    {
        var context = CreateContext(sourceComponent: "unknown", provenance: ContractRequestContext.SynthesizedProvenance);

        var exception = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            CreateContract().CheckAsync(
                new AccountComplianceRequest(Guid.NewGuid(), Guid.NewGuid()), context, CancellationToken.None));

        exception.Code.Should().Be(AccountComplianceContract.ConsumerDenied);
        _dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CheckAsync_RejectsTenantMismatch()
    {
        var exception = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            CreateContract().CheckAsync(
                new AccountComplianceRequest(Guid.NewGuid(), Guid.NewGuid()), CreateContext(), CancellationToken.None));

        exception.Code.Should().Be(AccountComplianceContract.TenantMismatch);
        _dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CheckAsync_MapsProviderFailureWithoutLeakingInternalException()
    {
        _dataPort.Setup(port => port.IsInvestmentAccountKycApprovedAsync(
                It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("database-secret"));

        var exception = await Assert.ThrowsAsync<AccountComplianceContractException>(() =>
            CreateContract().CheckAsync(
                new AccountComplianceRequest(Guid.NewGuid(), TenantId), CreateContext(), CancellationToken.None));

        exception.Code.Should().Be(AccountComplianceContract.Unavailable);
        exception.InnerException.Should().BeNull();
        exception.Message.Should().NotContain("database-secret");
    }

    [Fact]
    public async Task CheckAsync_PropagatesCancellation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => CreateContract().CheckAsync(
            new AccountComplianceRequest(Guid.NewGuid(), TenantId), CreateContext(), cancellation.Token));
    }

    private AccountComplianceContract CreateContract() => new(_dataPort.Object, _scopeFactory.Object);

    private static ContractRequestContext CreateContext(
        string sourceComponent = "transaction",
        string provenance = ContractRequestContext.TrustedProvenance) => new(
        Guid.NewGuid(),
        Guid.Parse("60a0e08c-2dd9-4f76-af07-e624f5adbe53"),
        Guid.Parse("1571d680-91cf-4f7c-853d-49cb816376e7"),
        ContractRequestContext.TenantScope,
        TenantId,
        "user",
        "actor-1",
        "ifx",
        sourceComponent,
        1,
        provenance);
}
