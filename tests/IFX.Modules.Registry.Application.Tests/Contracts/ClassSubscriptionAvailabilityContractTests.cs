using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.Registry.Application.Contracts;
using IFX.Modules.Registry.Application.Ports;
using IFX.Modules.Registry.Contracts.V1;
using IFX.Platform.Context.Contracts.Context;

namespace IFX.Modules.Registry.Application.Tests.Contracts;

public sealed class ClassSubscriptionAvailabilityContractTests
{
    private static readonly Guid TenantId = Guid.Parse("0cbe9224-d0aa-485f-9515-ccf71a584d71");
    private readonly Mock<IClassSubscriptionDataPort> _dataPort = new();
    private readonly Mock<IExecutionContextScopeFactory> _scopeFactory = new();

    public ClassSubscriptionAvailabilityContractTests()
    {
        _scopeFactory.Setup(factory => factory.Push(It.IsAny<ExecutionContextSnapshot>()))
            .Returns(Mock.Of<IDisposable>());
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task CheckAsync_ReturnsProviderOwnedDomainDecision(bool isOpen)
    {
        _dataPort.Setup(port => port.IsClassOpenForSubscriptionAsync(
                It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(isOpen);

        var response = await CreateContract().CheckAsync(
            new ClassSubscriptionAvailabilityRequest(Guid.NewGuid(), TenantId),
            CreateContext(),
            CancellationToken.None);

        response.IsOpen.Should().Be(isOpen);
    }

    [Fact]
    public async Task CheckAsync_RejectsUntrustedContext()
    {
        var exception = await Assert.ThrowsAsync<ClassSubscriptionAvailabilityContractException>(() =>
            CreateContract().CheckAsync(
                new ClassSubscriptionAvailabilityRequest(Guid.NewGuid(), TenantId),
                CreateContext(ContractRequestContext.SynthesizedProvenance),
                CancellationToken.None));

        exception.Code.Should().Be(ClassSubscriptionAvailabilityContract.ContextInvalid);
        _dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CheckAsync_RejectsTenantMismatch()
    {
        var exception = await Assert.ThrowsAsync<ClassSubscriptionAvailabilityContractException>(() =>
            CreateContract().CheckAsync(
                new ClassSubscriptionAvailabilityRequest(Guid.NewGuid(), Guid.NewGuid()),
                CreateContext(),
                CancellationToken.None));

        exception.Code.Should().Be(ClassSubscriptionAvailabilityContract.TenantMismatch);
        _dataPort.VerifyNoOtherCalls();
    }

    [Fact]
    public async Task CheckAsync_MapsProviderFailureToStableUnavailableCode()
    {
        _dataPort.Setup(port => port.IsClassOpenForSubscriptionAsync(
                It.IsAny<Guid>(), TenantId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new TimeoutException());

        var exception = await Assert.ThrowsAsync<ClassSubscriptionAvailabilityContractException>(() =>
            CreateContract().CheckAsync(
                new ClassSubscriptionAvailabilityRequest(Guid.NewGuid(), TenantId),
                CreateContext(),
                CancellationToken.None));

        exception.Code.Should().Be(ClassSubscriptionAvailabilityContract.Unavailable);
        exception.InnerException.Should().BeNull();
    }

    private ClassSubscriptionAvailabilityContract CreateContract() => new(_dataPort.Object, _scopeFactory.Object);

    private static ContractRequestContext CreateContext(
        string provenance = ContractRequestContext.TrustedProvenance) => new(
        Guid.NewGuid(),
        Guid.Parse("60a0e08c-2dd9-4f76-af07-e624f5adbe53"),
        Guid.Parse("1571d680-91cf-4f7c-853d-49cb816376e7"),
        ContractRequestContext.TenantScope,
        TenantId,
        "service",
        "transaction-service",
        "ifx",
        "transaction",
        1,
        provenance);
}
